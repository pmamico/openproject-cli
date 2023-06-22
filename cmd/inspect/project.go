package inspect

import (
	"fmt"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/opf/openproject-cli/components/printer"
	"github.com/opf/openproject-cli/components/resources/projects"
)

var inspectProjectCmd = &cobra.Command{
	Use:   "project [id]",
	Short: "Show details about a project",
	Long:  "Show detailed information of a project refereced by it's ID.",
	Run:   execute,
}

func execute(_ *cobra.Command, args []string) {
	id, err := strconv.ParseInt(args[0], 10, 64)
	if err != nil {
		printer.ErrorText(fmt.Sprintf("'%s' is an invalid work package id. Must be a number.", args[0]))
	}

	pro := projects.Find(id)
	printer.Projects(pro)
}
