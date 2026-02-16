package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "docgen",
	Short: "Documentation generator for Open Platform Model",
	Long: `docgen extracts high-fidelity schema information from CUE definitions
and generates structured JSON for Hugo consumption. It also generates
CLI reference documentation from cobra command trees.`,
}

var schemaCmd = &cobra.Command{
	Use:   "schema",
	Short: "Generate schema JSON from CUE definitions",
	Long: `Walk CUE definitions in the catalog and produce structured JSON
files containing definition metadata, fields, types, constraints,
defaults, and cross-references.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		catalogDir, _ := cmd.Flags().GetString("catalog-dir")
		outputDir, _ := cmd.Flags().GetString("output")

		fmt.Printf("Generating schema docs from %s -> %s\n", catalogDir, outputDir)
		// TODO: Implement CUE schema extraction
		return fmt.Errorf("not implemented yet")
	},
}

var cliCmd = &cobra.Command{
	Use:   "cli",
	Short: "Generate CLI reference markdown from cobra commands",
	Long: `Generate markdown reference documentation for the OPM CLI
using cobra's built-in doc generation with Hugo front matter.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		outputDir, _ := cmd.Flags().GetString("output")

		fmt.Printf("Generating CLI docs -> %s\n", outputDir)
		// TODO: Implement cobra doc generation
		return fmt.Errorf("not implemented yet")
	},
}

var allCmd = &cobra.Command{
	Use:   "all",
	Short: "Generate all documentation (schema + CLI)",
	RunE: func(cmd *cobra.Command, args []string) error {
		catalogDir, _ := cmd.Flags().GetString("catalog-dir")
		outputDir, _ := cmd.Flags().GetString("output")

		fmt.Printf("Generating all docs from %s -> %s\n", catalogDir, outputDir)
		// TODO: Run both schema and CLI generation
		return fmt.Errorf("not implemented yet")
	},
}

func init() {
	schemaCmd.Flags().StringP("catalog-dir", "c", "../catalog", "Path to catalog repository")
	schemaCmd.Flags().StringP("output", "o", "./site/data/schema", "Output directory for JSON files")

	cliCmd.Flags().StringP("output", "o", "./site/content/reference/cli", "Output directory for markdown files")

	allCmd.Flags().StringP("catalog-dir", "c", "../catalog", "Path to catalog repository")
	allCmd.Flags().StringP("output", "o", "./site", "Output directory")

	rootCmd.AddCommand(schemaCmd, cliCmd, allCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}
