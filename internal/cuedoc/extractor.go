package cuedoc

// Package cuedoc extracts high-fidelity schema information from CUE definitions
// using the cuelang.org/go/cue Go API. It preserves CUE-specific semantics like
// disjunctions, bounds constraints, optional/required markers, and cross-references
// that would be lost in an OpenAPI export.

import (
	"fmt"
)

// DefinitionDoc represents a complete CUE definition with all metadata
type DefinitionDoc struct {
	Name            string      `json:"name"`
	Kind            string      `json:"kind"`
	FQN             string      `json:"fqn"`
	Description     string      `json:"description,omitempty"`
	Fields          []FieldDoc  `json:"fields"`
	SpecDescription string      `json:"spec_description,omitempty"`
	Related         []Reference `json:"related,omitempty"`
}

// FieldDoc represents a single field in a definition
type FieldDoc struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Type        string `json:"type"`
	Constraint  string `json:"constraint,omitempty"`
	Required    bool   `json:"required"`
	Description string `json:"description,omitempty"`
	Default     string `json:"default,omitempty"`
}

// Reference represents a cross-reference to another definition
type Reference struct {
	Type   string `json:"type"`   // "appliesTo", "uses", etc.
	Target string `json:"target"` // FQN of target definition
	Label  string `json:"label"`  // Human-readable label
}

// ModuleDoc represents a complete CUE module with all its definitions
type ModuleDoc struct {
	Module      string          `json:"module"`
	Version     string          `json:"version"`
	Definitions []DefinitionDoc `json:"definitions"`
}

// Extract walks a CUE module and produces structured documentation
func Extract(catalogDir string, outputDir string) error {
	// TODO: Implement using cuelang.org/go/cue API
	// - load.Instances() to load CUE modules
	// - Value.Fields() to iterate definitions
	// - Value.Doc() to extract comments
	// - Value.Default(), Value.IncompleteKind(), Value.Expr() for metadata
	return fmt.Errorf("not implemented yet")
}
