package applicationpools

import (
	"encoding/json"
	"fmt"
	"strings"
	"strconv"
)

type getValue struct {
	Value bool
}
// GetEnable32Bit will return Enable 32-Bit Application status of an Application Pool within IIS.
func (c *AppPoolsClient) GetEnable32Bit(name string) (bool, error) {
	commands := fmt.Sprintf(`
Import-Module WebAdministration
Get-ItemProperty "IIS:\AppPools\%s" enable32BitAppOnWin64 | select-object value | conver
tto-json
  `, name)

	stdout, _, err := c.Run(commands)
	if err != nil {
		return false, fmt.Errorf("Error retrieving App Pool %q: %+v", name, err)
	}

	var enable32BitStatus getValue
	if out := stdout; out != nil && *out != "" {
		v := *out
		err := json.Unmarshal([]byte(v), &enable32BitStatus)
		if err != nil {
			return false, fmt.Errorf("Error unmarshalling App Pool %q: %+v", name, err)
		}
	}

	return enable32BitStatus.Value, nil
}

// SetEnable32Bit will set 'Enable 32-Bit Application' value to an Application Pool within IIS.
func (c *AppPoolsClient) SetEnable32Bit(name string, value bool) error {
	commands := fmt.Sprintf(`
Import-Module WebAdministration
set-ItemProperty "IIS:\AppPools\%q" enable32BitAppOnWin64  -Value true
  `, name, strconv.FormatBool(value))

	_, stderr, err := c.Run(commands)
	if err != nil {
		return fmt.Errorf("Error setting Enable32-bitApp to App Pool %q: %+v", name, err)
	}

	if serr := stderr; serr != nil {
		v := strings.TrimSpace(*serr)
		if v != "" {
			return fmt.Errorf("Error setting Enable32-bitApp to App Pool %q: %s", name, v)
		}
	}

	return nil
}
