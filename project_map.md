### Projekt Struktúra és Fájltérkép

```text
├── app/
│   ├── channels/
│   │   ├── application_cable/
│   │   │   ├── channel.rb
│   │   │   └── connection.rb
│   │   ├── global_chat_channel.rb
│   │   ├── presence_channel.rb
│   │   ├── server_metrics_channel.rb
│   │   └── test_channel.rb
│   ├── controllers/
│   │   ├── admin/
│   │   │   ├── apps_controller.rb
│   │   │   ├── audit_logs_controller.rb
│   │   │   ├── base_controller.rb
│   │   │   ├── dashboard_controller.rb
│   │   │   ├── server_metrics_controller.rb
│   │   │   └── users_controller.rb
│   │   ├── application_controller.rb
│   │   ├── chat_messages_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── pages_controller.rb
│   │   ├── profiles_controller.rb
│   │   ├── registrations_controller.rb
│   │   ├── sessions_controller.rb
│   │   └── test_controller.rb
│   ├── helpers/
│   │   └── application_helper.rb
│   ├── models/
│   │   ├── active_session.rb
│   │   ├── app_definition.rb
│   │   ├── application_record.rb
│   │   ├── audit_log.rb
│   │   ├── chat_message.rb
│   │   ├── user.rb
│   │   └── user_app_permission.rb
│   ├── services/
│   │   ├── profile_widgets/
│   │   │   ├── account_security_widget.rb
│   │   │   ├── activity_logs_widget.rb
│   │   │   ├── base_widget.rb
│   │   │   ├── casino_stats_widget.rb
│   │   │   ├── chess_stats_widget.rb
│   │   │   ├── overview_widget.rb
│   │   │   └── profile_widget_registry.rb
│   │   ├── app_backup_service.rb
│   │   └── server_metrics_service.rb
│   └── views/
│       ├── admin/
│       │   ├── apps/
│       │   │   ├── edit.html.erb
│       │   │   └── index.html.erb
│       │   ├── audit_logs/
│       │   │   └── index.html.erb
│       │   ├── dashboard/
│       │   │   └── index.html.erb
│       │   ├── server_metrics/
│       │   │   └── index.html.erb
│       │   └── users/
│       │       ├── edit.html.erb
│       │       └── index.html.erb
│       ├── dashboard/
│       │   └── index.html.erb
│       ├── layouts/
│       │   ├── admin.html.erb
│       │   └── application.html.erb
│       ├── pages/
│       │   ├── about.html.erb
│       │   ├── privacy.html.erb
│       │   └── terms.html.erb
│       ├── profiles/
│       │   ├── widgets/
│       │   │   ├── _account_security.html.erb
│       │   │   ├── _activity_logs.html.erb
│       │   │   ├── _casino_stats.html.erb
│       │   │   ├── _chess_stats.html.erb
│       │   │   └── _overview.html.erb
│       │   ├── _edit_modal.html.erb
│       │   ├── _widget_container.html.erb
│       │   └── show.html.erb
│       ├── registrations/
│       │   └── new.html.erb
│       ├── sessions/
│       │   └── new.html.erb
│       ├── shared/
│       │   ├── _design_system.html.erb
│       │   ├── _footer.html.erb
│       │   ├── _global_chat.html.erb
│       │   ├── _navbar.html.erb
│       │   └── app_disabled.html.erb
│       └── test/
│           └── index.html.erb
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   └── production.rb
│   ├── initializers/
│   │   ├── content_security_policy.rb
│   │   ├── filter_parameter_logging.rb
│   │   ├── rack_attack.rb
│   │   ├── rate_limiter.rb
│   │   └── session_store.rb
│   ├── application.rb
│   ├── boot.rb
│   ├── cable.yml
│   ├── database.yml
│   ├── environment.rb
│   └── routes.rb
├── db/
│   ├── migrate/
│   │   ├── 20260904000001_create_users.rb
│   │   ├── 20260904000002_add_roles_and_security_to_users.rb
│   │   ├── 20260904000003_create_active_sessions.rb
│   │   ├── 20260904000004_create_app_definitions.rb
│   │   ├── 20260904000005_create_user_app_permissions.rb
│   │   ├── 20260904000006_create_audit_logs.rb
│   │   ├── 20260904000007_add_requires_login_to_app_definitions.rb
│   │   ├── 20260904000008_create_chess_matches.rb
│   │   ├── 20260904000009_create_chess_settings.rb
│   │   ├── 20260904000010_create_casino_tables.rb
│   │   ├── 20260904000011_register_casino_app_definition.rb
│   │   ├── 20260906000001_add_profile_fields_and_presence_to_users.rb
│   │   ├── 20260906000002_create_chat_messages.rb
│   │   └── 20260906000003_create_canvas_tables.rb
│   └── seeds.rb
├── docs/
│   └── legal/
│       ├── about_and_contact.md
│       ├── disclaimer_and_terms.md
│       └── privacy_policy.md
├── engines/
│   ├── canvas/
│   │   ├── app/
│   │   │   ├── channels/
│   │   │   │   └── canvas/
│   │   │   │       └── board_channel.rb
│   │   │   ├── controllers/
│   │   │   │   └── canvas/
│   │   │   │       ├── application_controller.rb
│   │   │   │       └── boards_controller.rb
│   │   │   ├── models/
│   │   │   │   └── canvas/
│   │   │   │       ├── board.rb
│   │   │   │       └── stroke.rb
│   │   │   └── views/
│   │   │       ├── canvas/
│   │   │       │   └── boards/
│   │   │       │       └── show.html.erb
│   │   │       └── layouts/
│   │   │           └── canvas/
│   │   │               └── application.html.erb
│   │   ├── config/
│   │   │   └── routes.rb
│   │   └── lib/
│   │       ├── canvas/
│   │       │   └── engine.rb
│   │       └── canvas.rb
│   ├── casino/
│   │   ├── app/
│   │   │   ├── channels/
│   │   │   │   └── casino/
│   │   │   │       └── table_channel.rb
│   │   │   ├── controllers/
│   │   │   │   └── casino/
│   │   │   │       ├── admin/
│   │   │   │       │   ├── base_controller.rb
│   │   │   │       │   ├── dashboard_controller.rb
│   │   │   │       │   ├── tables_controller.rb
│   │   │   │       │   └── users_controller.rb
│   │   │   │       ├── application_controller.rb
│   │   │   │       ├── leaderboards_controller.rb
│   │   │   │       ├── lobby_controller.rb
│   │   │   │       └── tables_controller.rb
│   │   │   ├── models/
│   │   │   │   └── casino/
│   │   │   │       ├── application_record.rb
│   │   │   │       ├── bet.rb
│   │   │   │       ├── profile.rb
│   │   │   │       ├── table.rb
│   │   │   │       └── transaction.rb
│   │   │   ├── services/
│   │   │   │   └── casino/
│   │   │   │       ├── baccarat_engine.rb
│   │   │   │       ├── blackjack_engine.rb
│   │   │   │       ├── roulette_engine.rb
│   │   │   │       └── table_manager.rb
│   │   │   └── views/
│   │   │       ├── casino/
│   │   │       │   ├── admin/
│   │   │       │   │   ├── dashboard/
│   │   │       │   │   │   └── index.html.erb
│   │   │       │   │   ├── tables/
│   │   │       │   │   │   └── index.html.erb
│   │   │       │   │   └── users/
│   │   │       │   │       ├── edit.html.erb
│   │   │       │   │       └── index.html.erb
│   │   │       │   ├── leaderboards/
│   │   │       │   │   └── index.html.erb
│   │   │       │   ├── lobby/
│   │   │       │   │   └── index.html.erb
│   │   │       │   └── tables/
│   │   │       │       └── show.html.erb
│   │   │       └── layouts/
│   │   │           └── casino/
│   │   │               ├── admin.html.erb
│   │   │               └── application.html.erb
│   │   ├── config/
│   │   │   └── routes.rb
│   │   └── lib/
│   │       ├── casino/
│   │       │   ├── engine.rb
│   │       │   └── scheduler.rb
│   │       └── casino.rb
│   └── chess/
│       ├── app/
│       │   ├── channels/
│       │   │   └── chess/
│       │   │       └── match_channel.rb
│       │   ├── controllers/
│       │   │   └── chess/
│       │   │       ├── admin/
│       │   │       │   ├── base_controller.rb
│       │   │       │   ├── dashboard_controller.rb
│       │   │       │   ├── matches_controller.rb
│       │   │       │   └── settings_controller.rb
│       │   │       ├── application_controller.rb
│       │   │       ├── dashboard_controller.rb
│       │   │       └── matches_controller.rb
│       │   ├── models/
│       │   │   └── chess/
│       │   │       ├── application_record.rb
│       │   │       ├── match.rb
│       │   │       └── setting.rb
│       │   └── views/
│       │       ├── chess/
│       │       │   ├── admin/
│       │       │   │   ├── dashboard/
│       │       │   │   │   └── index.html.erb
│       │       │   │   ├── matches/
│       │       │   │   │   ├── index.html.erb
│       │       │   │   │   └── show.html.erb
│       │       │   │   └── settings/
│       │       │   │       └── edit.html.erb
│       │       │   ├── dashboard/
│       │       │   │   └── index.html.erb
│       │       │   └── matches/
│       │       │       ├── index.html.erb
│       │       │       └── show.html.erb
│       │       └── layouts/
│       │           └── chess/
│       │               ├── admin.html.erb
│       │               └── application.html.erb
│       ├── config/
│       │   └── routes.rb
│       └── lib/
│           ├── chess/
│           │   └── engine.rb
│           └── chess.rb
├── public/
│   ├── vendor/
│   │   ├── actioncable/
│   │   │   └── actioncable.js
│   │   ├── chartjs/
│   │   │   └── chart.umd.min.js
│   │   ├── chess/
│   │   │   ├── img/
│   │   │   │   └── chesspieces/
│   │   │   │       └── wikipedia/
│   │   │   ├── chess.min.js
│   │   │   ├── chessboard-1.0.0.min.css
│   │   │   ├── chessboard-1.0.0.min.js
│   │   │   └── jquery-3.6.0.min.js
│   │   └── fonts/
│   └── robots.txt
├── .gitignore
├── config.ru
├── deploy.sh
├── Gemfile
├── generate_map.py
├── generate_map.txt
├── LICENSE
├── main.txt
├── project_context.md
├── Rakefile
└── VERSION
```
