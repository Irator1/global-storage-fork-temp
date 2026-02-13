# Changelog

## v0.3.5
All changes from original mod (charlesbl v0.1.2):
- Sequential link_id allocation — fixes hash collision bugs where two network names could silently share inventory
- Copy-paste from assemblers — auto-creates network named by sorted ingredients, sets item requests automatically
- Configurable chest size via startup setting (default 48, range 1–256)
- Full quality item support via composite key system ("item-name:quality") with quality-aware processing, GUI selectors, player logistics, and HUD pins
- Native Factorio quality rendering on all GUI buttons
- "Remove" button for deleting items from global inventory
- UI improvements — wider panels, network name truncation with tooltips, 7-column request grid, frame width caps
- Hidden optional dependency on quality mod for Space Age compatibility
- Dead code and unused locale cleanup
