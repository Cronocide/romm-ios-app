# Info.plist Configuration for OIDC

## Required: URL Scheme Setup

For OIDC callback to work, you must add a custom URL scheme to your `Info.plist`.

### Steps in Xcode:

1. Open your project in Xcode
2. Select your target
3. Go to "Info" tab
4. Add a new "URL Types" entry:

```
URL Types:
  - Item 0:
      Document Role: Editor
      URL Identifier: com.romm.app
      URL Schemes:
        - Item 0: romm
```

### Or manually in Info.plist:

Add this to your `Info.plist` file:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.romm.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>romm</string>
        </array>
    </dict>
</array>
```

### What this does:

- Registers `romm://` as a custom URL scheme
- When the OIDC server redirects to `romm://callback`, your app will open
- ASWebAuthenticationSession captures this callback
- The authorization code is extracted from the URL

### Testing the URL Scheme:

You can test if it's configured correctly by opening Safari and entering:
```
romm://test
```

Your app should open (or iOS will offer to open it).

### Customizing the URL Scheme:

If you want to use a different scheme:
1. Change `romm` to your preferred scheme in Info.plist
2. Update `OIDCAuthService.defaultRedirectURI` to match
3. Make sure your OIDC server is configured with the same redirect URI

**Default Configuration:**
- Scheme: `romm`
- Callback: `romm://callback`
- Service: `OIDCAuthService.defaultRedirectURI`
