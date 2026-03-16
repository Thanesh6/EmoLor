# EmoLor Flutter Setup Script
# This script copies the Flutter app files to your Flutter project and sets it up

Write-Host "🚀 EmoLor Flutter Setup" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$sourceLib = "flutter_app\lib"
$targetProject = "..\emolor_flutter"
$targetLib = "$targetProject\lib"

# Check if Flutter project exists
if (-Not (Test-Path $targetProject)) {
    Write-Host "❌ Flutter project not found at: $targetProject" -ForegroundColor Red
    Write-Host "   Creating Flutter project..." -ForegroundColor Yellow
    cd ..
    flutter create emolor_flutter --org com.emolor --platforms=android,ios,web
    cd EmoLor
    Write-Host "✅ Flutter project created!" -ForegroundColor Green
}

# Copy lib files
Write-Host "📁 Copying Flutter app files..." -ForegroundColor Yellow
if (Test-Path $sourceLib) {
    Copy-Item -Path "$sourceLib\*" -Destination $targetLib -Recurse -Force
    Write-Host "✅ Files copied successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Source files not found at: $sourceLib" -ForegroundColor Red
    exit 1
}

# Navigate to Flutter project
cd $targetProject

# Get dependencies
Write-Host ""
Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  IMPORTANT: Update your Supabase credentials" -ForegroundColor Yellow
Write-Host "   File: lib\core\constants\app_constants.dart" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Update Supabase URL and anon key in app_constants.dart"
Write-Host "   2. Run: flutter run -d chrome (for web)"
Write-Host "   3. Run: flutter run -d windows (for Windows)"
Write-Host ""
Write-Host "📖 See FLUTTER_NEXT_STEPS.md for detailed guide" -ForegroundColor Cyan
