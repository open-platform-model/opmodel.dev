package cobradoc

// Package cobradoc generates CLI reference documentation from cobra command trees
// using github.com/spf13/cobra/doc with Hugo front matter prependers.

import (
	"fmt"
)

// Generate produces markdown reference docs for cobra commands with Hugo front matter
func Generate(outputDir string) error {
	// TODO: Implement using cobra/doc.GenMarkdownTreeCustom
	// - Import opm CLI root command as dependency
	// - Add Hugo front matter prepender
	// - Generate cross-linked markdown files
	return fmt.Errorf("not implemented yet")
}
