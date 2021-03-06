package websites

import (
	"fmt"
	// "log"
)

func (c *WebsitesClient) Create(name string, applicationPool string, physicalPath string, port int, domainName string) error {
	// we normalize the path via PS as otherwise AppSettings/AuthMode fails
	// when combining `C:\\inetpub\\site\web.config` (also fails on C:/inetpub/site\web.config`)
	commands := fmt.Sprintf(`
Import-Module WebAdministration
$path = [IO.Path]::GetFullPath(%q)
New-Website -Name %q -ApplicationPool %q -PhysicalPath $path -Port %d -HostHeader %q
  `, physicalPath, name, applicationPool, port, domainName)

	_, stderr, err := c.Run(commands)
	if err != nil {
		return fmt.Errorf("Error#1 creating Website: %+v", err)
	}

	if stderr != nil && *stderr != "" {
		return fmt.Errorf("Error#2 creating Website %q: %+v", name, err)
	}

	return nil
}
