# frozen_string_literal: true

# ==============================================================================
# Bánk's Repository - JSON quirks_mode Kompatibilitási Javítás
# ==============================================================================
# Megelőzi az "unknown keyword: quirks_mode" kivételt a Rails 7.1 süti és
# munkamenet-visszafejtési folyamataiban a JSON gem újabb verziói mellett.
# ==============================================================================

# JSON quirks_mode compatibility is configured early in config/boot.rb.


