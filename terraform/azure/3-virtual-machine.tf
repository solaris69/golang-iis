locals {
  custom_data_params  = "Param($ComputerName = \"${local.virtual_machine_name}\")"
  custom_data_content = "${local.custom_data_params} ${file("./files/winrm.ps1")}"
  checkout_path       = "C:\\Users\\${local.admin_username}\\go\\src\\github.com\\tombuildsstuff\\golang-iis"
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${local.virtual_machine_name}"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_F2"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.prefix}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name}"
    admin_username = "${local.admin_username}"
    admin_password = "${local.admin_password}"
    custom_data    = "${local.custom_data_content}"
  }

  os_profile_secrets {
    source_vault_id = "${azurerm_key_vault.main.id}"

    vault_certificates {
      certificate_url   = "${azurerm_key_vault_certificate.main.secret_id}"
      certificate_store = "My"
    }
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${local.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${local.admin_username}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("./files/FirstLogonCommands.xml")}"
    }
  }

  provisioner "remote-exec" {
    connection {
      user     = "${local.admin_username}"
      password = "${local.admin_password}"
      port     = 5986
      https    = true
      timeout  = "10m"

      # NOTE: if you're using a real certificate, rather than a self-signed one, you'll want this set to `false`/to remove this.
      insecure = true
    }

    inline = [
      "mkdir C:\\temp",
      "cd C:\\temp",
      "powershell.exe -Command (New-Object Net.WebClient).DownloadFile('https://dl.google.com/go/go1.10.3.windows-amd64.msi', 'C:\\temp\\golang.msi')",
      "msiexec /i C:\\temp\\golang.msi /qn /norestart",
      "mkdir ${local.checkout_path}",
      "powershell.exe -Command Import-Module ServerManager; Add-WindowsFeature -Name Web-Common-Http,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Request-Monitor,Web-Basic-Auth,Web-Windows-Auth,Web-Filtering,Web-Performance,Web-Mgmt-Console,Web-Mgmt-Compat,WAS -IncludeAllSubFeature",
      # TODO: install Make
    ]
  }

  tags = "${local.tags}"
}
