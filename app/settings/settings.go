package settings

import (
	"io/ioutil"

	yaml "github.com/go-yaml/yaml"
	"github.com/nanu-c/axolotl/app/config"
	log "github.com/sirupsen/logrus"
)

// Model for application settings

type Settings struct {
	SendByEnter     bool   `yaml:"sendByEnter"`
	EncryptDatabase bool   `yaml:"encryptDatabase"`
	CountryCode     string `yaml:"countrysDatabase"`
	Registered      bool   `yaml:"registered"`
	DebugLog        bool   `yaml:"debugLog"`
}

var SettingsModel *Settings

//Load the Settings
func LoadSettings() (*Settings, error) {
	s := &Settings{}

	b, err := ioutil.ReadFile(config.SettingsFile)
	if err != nil {
		return s, err
	}
	err = yaml.Unmarshal(b, s)
	if err != nil {
		return s, err
	}
	test := &s.DebugLog
	if test != nil {
		if s.DebugLog == true {
			log.SetLevel(log.DebugLevel)
		}
	}
	SettingsModel = s

	return s, nil
}

//Save the Settings
func SaveSettings(s *Settings) error {
	b, err := yaml.Marshal(s)
	if err != nil {
		return err
	}
	return ioutil.WriteFile(config.SettingsFile, b, 0600)
}
