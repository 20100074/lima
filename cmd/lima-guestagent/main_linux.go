package main

import (
	"errors"
	"os"
	"strings"

	"github.com/lima-vm/lima/pkg/version"
	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

func main() {
	if err := newApp().Run(os.Args); err != nil {
		logrus.Fatal(err)
	}
}

func newApp() *cli.App {
	app := cli.NewApp()
	app.Name = "lima-guestagent"
	app.Usage = "Do not launch manually"
	app.Version = strings.TrimPrefix(version.Version, "v")
	app.Flags = []cli.Flag{
		&cli.BoolFlag{
			Name:  "debug",
			Usage: "debug mode",
		},
	}
	app.Before = func(clicontext *cli.Context) error {
		if clicontext.Bool("debug") {
			logrus.SetLevel(logrus.DebugLevel)
		}
		if os.Geteuid() == 0 {
			return errors.New("must not run as the root")
		}
		return nil
	}
	app.Commands = []*cli.Command{
		daemonCommand,
		installSystemdCommand,
	}
	return app
}
