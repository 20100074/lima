//go:build !darwin
// +build !darwin

package osutil

import (
  "bufio"
  "fmt"
  "os"
  "strings"
)

func ReadDNSSettings() (filename string) {
  // cat /run/systemd/resolve/resolv.conf

  var availableDNS []string
  file, err := os.Open(filename)
  if err != nil {
    return err.s();
  }

  s := bufio.NewScanner(file)
  for s.Scan() {
    // if line contains nameserver,
    if strings.Contains(s.Text(), 'nameserver') {
      // each line contains DNS address
      // FIXME: fmt.Printf doesn't return string
      // availableDNS = append(fmt.Printf("%s", strings.TrimLeft(s.Text(), "nameserver ")), availableDNS)
      availableDNS := append(availableDNS, strings.TrimLeft(s.Text(), "nameserver "))
    }
  }
  if s.Err() != nil {
    return s.Err().Text()
  }

  return availableDNS
}

func DNSAddresses() ([]string, error) {
	// TODO: parse /etc/resolv.conf?
	// cat /run/systemd/resolve/resolv.conf | grep nameserver | gawk '{print $2}'
	return []string{}, nil
}

func ProxySettings() (map[string]string, error) {
	return make(map[string]string), nil
}
