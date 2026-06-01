# EMOLOR - Flutter setup (Android tablet only)
#
# Prerequisites:
#   - Flutter SDK (Dart >=3.0.0 <4.0.0)
#   - A connected Android tablet or emulator (find its id with: flutter devices)
#
# Secrets are NEVER committed. They are supplied at run time via --dart-define.

Write-Host "EMOLOR Flutter setup" -ForegroundColor Cyan

# 1. Fetch dependencies
Set-Location mobile_app
flutter pub get

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Run the app on a connected Android device with:" -ForegroundColor Cyan
Write-Host "  flutter run -d <android-device-id> ``" -ForegroundColor White
Write-Host "    --dart-define=SUPABASE_URL=https://<project>.supabase.co ``" -ForegroundColor White
Write-Host "    --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key> ``" -ForegroundColor White
Write-Host "    --dart-define=ANTHROPIC_API_KEY=<anthropic-api-key>" -ForegroundColor White
