import Config

# The library's own build, for its tests. A site's Ash config is its own:
# these match the backwards-compatibility settings Ash's installer writes,
# and the ones Stylish Strands uses, so components behave here as they do
# there. See https://hexdocs.pm/ash/backwards-compatibility-config.html
config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  many_to_many_destroy_destination_on_match?: true

import_config "#{config_env()}.exs"
