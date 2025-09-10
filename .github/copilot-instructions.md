# Copilot Instructions for Lilac Discord Plugin

## Repository Overview
This repository contains a SourceMod plugin that sends Little Anti-Cheat (Lilac) detection notifications to Discord channels via webhooks. The plugin integrates with multiple other SourceMod plugins to provide comprehensive cheat detection reporting with optional demo recording information and extended Discord functionality.

**Main Plugin File**: `addons/sourcemod/scripting/Lilac_Discord.sp`

## Technical Environment
- **Language**: SourcePawn
- **Platform**: SourceMod 1.11.0+ (as specified in sourceknight.yaml)
- **Build System**: SourceKnight 0.2
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **CI/CD**: GitHub Actions with automated building, tagging, and releases

## Dependencies
The plugin requires several external dependencies managed by SourceKnight:
- **SourceMod**: Core SourceMod framework (1.11.0-git6934)
- **Lilac**: Little Anti-Cheat plugin (required for cheat detection events)
- **DiscordWebhookAPI**: Discord webhook functionality (required)
- **Extended-Discord**: Extended Discord features (optional)
- **AutoRecorder**: Demo recording integration (optional)

## Code Style & Standards
Follow these specific conventions for this project:

### SourcePawn Standards
- Use `#pragma semicolon 1` and `#pragma newdecls required` at file start
- Indentation: 4 spaces (tabs converted to spaces)
- Use camelCase for local variables and function parameters
- Use PascalCase for function names
- Prefix global variables with "g_" (e.g., `g_cvEnable`, `g_Plugin_ExtDiscord`)
- Use descriptive variable names (e.g., `sCheatDetails`, `sWebhookURL`)

### Memory Management
- Always use `delete` for cleanup without null checks (SourceMod handles null gracefully)
- Use `delete` instead of `.Clear()` for StringMap/ArrayList to prevent memory leaks
- Create new instances instead of clearing existing ones
- This plugin demonstrates proper cleanup: `delete webhook;`, `delete Footer;`, `delete pack;`

### Plugin Integration
- Use `LibraryExists()` to check for optional plugin availability in `OnAllPluginsLoaded()`
- Implement proper library added/removed handlers using `OnLibraryAdded()` and `OnLibraryRemoved()`
- Use conditional compilation with `#if defined` for optional features (see AutoRecorder integration)
- Use `#tryinclude` for optional plugin headers
- Store plugin availability in global boolean variables (e.g., `g_Plugin_ExtDiscord`, `g_Plugin_AutoRecorder`)

## Project Structure
```
addons/sourcemod/scripting/
├── Lilac_Discord.sp          # Main plugin file
sourceknight.yaml             # Build configuration
.github/workflows/ci.yml      # CI/CD pipeline
.github/copilot-instructions.md # This file
```

### Key Components in Main Plugin
- **Configuration**: ConVar system for all settings (webhook URL, retry count, etc.)
- **Event Handling**: `lilac_cheater_detected()` - main detection handler
- **Discord Integration**: `SendLilacDiscordMessage()` - webhook message builder with embed creation
- **Error Handling**: `OnWebHookExecuted()` - async response handler with retry logic
- **Optional Features**: Conditional compilation for AutoRecorder and ExtendedDiscord
- **Library Management**: Dynamic plugin detection using `LibraryExists()` and event handlers

## Build & Validation Process

### Building the Plugin
```bash
# SourceKnight automatically handles dependencies and compilation
# Build is triggered via GitHub Actions or SourceKnight CLI
```

### Testing Changes
1. **Syntax Validation**: SourceKnight will catch compilation errors
2. **Runtime Testing**: Deploy to test server with Lilac anti-cheat active
3. **Discord Testing**: Verify webhook delivery to Discord channels/threads
4. **Integration Testing**: Test with optional plugins enabled/disabled

### Configuration Testing
Test with various ConVar configurations:
- Different webhook URLs and retry settings
- Thread vs. classic channel modes
- With/without optional plugin integrations

## Common Development Tasks

### Adding New Discord Fields
1. Create the field data in `lilac_cheater_detected()`
2. Add EmbedField creation in `SendLilacDiscordMessage()`
3. Update the DataPack read/write operations for retry functionality
4. Ensure proper memory cleanup with `delete` for new EmbedField objects

### Modifying Webhook Behavior
- Edit `SendLilacDiscordMessage()` for webhook structure changes
- Update `OnWebHookExecuted()` for response handling modifications
- Ensure proper error handling and retry logic
- Remember to clean up webhook objects with `delete`

### Adding New Optional Plugin Integration
1. Add `#tryinclude` for the plugin header
2. Add library existence checks in `OnAllPluginsLoaded()`
3. Implement library added/removed handlers using `OnLibraryAdded()` and `OnLibraryRemoved()`
4. Use conditional compilation with `#if defined` for plugin-specific features
5. Add boolean global variables (prefixed with `g_Plugin_`) to track plugin availability

### Debugging Missing Functions
If you encounter undefined function errors (like `GetCheatName`):
1. Check if the function should be provided by Lilac includes
2. Verify all required include files are properly referenced
3. Check SourceKnight dependency configuration for missing plugins
4. Consider implementing the function as a stock function if it's a utility

## Performance Considerations
- Webhook calls are asynchronous - avoid blocking operations
- Use DataPack for retry operations to maintain context
- Minimize string operations in frequently called functions
- Cache ConVar values when appropriate (avoid repeated GetString calls)
- Consider rate limiting for multiple rapid detections

## Error Handling Best Practices
- Always validate webhook URL before sending
- Implement retry logic with configurable limits
- Log errors appropriately (use ExtendedDiscord if available)
- Handle client disconnection during webhook processing
- Gracefully handle missing optional plugins

## Integration Points

### With Lilac Anti-Cheat
- Hooks into `lilac_cheater_detected()` forward
- Calls `lilac_GetDetectedInfos()` for detection details
- Requires proper cheat type name resolution

### With AutoRecorder (Optional)
- Provides demo recording information in notifications
- Includes tick position and recording timestamps
- Conditional compilation ensures plugin works without it

### With Extended-Discord (Optional)
- Enhanced error logging capabilities
- Additional Discord integration features

## Configuration Management
All settings use SourceMod's ConVar system:
- **Security**: Use `FCVAR_PROTECTED` for sensitive data (webhook URLs)
- **Validation**: Implement proper bounds checking for numeric values
- **Auto-config**: Use `AutoExecConfig(true, PLUGIN_NAME)` for automatic .cfg generation

## Version Control Guidelines
- Update version string in plugin info when making releases
- Use semantic versioning aligned with Git tags
- Keep commit messages descriptive for build and detection changes
- CI automatically creates releases from Git tags

## Testing Webhooks
For development and testing:
1. Use Discord webhook testing tools or create test channels
2. Test both thread and classic channel modes
3. Verify embed formatting and field content
4. Test retry logic with temporary webhook failures
5. Validate optional plugin integration states

## Common Pitfalls to Avoid
- Don't use synchronous HTTP requests for webhooks
- Don't forget to handle client disconnection in async callbacks
- Don't hardcode Discord limits - use defined constants
- Don't skip null validation for ConVar string retrievals
- Don't use `.Clear()` on containers - use `delete` and recreate
- Always consider the case where optional plugins are not loaded