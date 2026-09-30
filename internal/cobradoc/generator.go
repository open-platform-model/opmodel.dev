// Package cobradoc generates CLI reference documentation from cobra command trees
// using github.com/spf13/cobra/doc, with Hugo front matter on every page.
package cobradoc

import (
	"fmt"
)

// Generate produces markdown reference docs for cobra commands with Hugo front matter.
func Generate(outputDir string) error {
	// TODO: Implement using cobra/doc.GenMarkdownTreeCustom
	// - Import opm CLI root command as dependency
	// - Prepend Hugo front matter (title, description, weight)
	// - Generate cross-linked markdown files
	return fmt.Errorf("not implemented yet")
}
