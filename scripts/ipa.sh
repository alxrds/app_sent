#!/bin/zsh
# Gera o IPA da App Store sem iPhone cadastrado.
# O `flutter build ipa` assina o archive com perfil de desenvolvimento, que
# exige aparelho registrado no time. Aqui o archive não usa perfil e só
# a exportação assina de verdade, com o certificado de distribuição gerenciado pela
# Apple (não depende de aparelho). Antes de exportar, o Runner.entitlements
# (push) é gravado no app do archive; sem isso a
# exportação sai sem essas permissões. O Xcode 27 recusa assinatura ad-hoc
# no próprio archive, por isso é feito à parte com o codesign. Saída: o .ipa em build/ios/ipa/
set -euo pipefail
cd "$(dirname "$0")/.."

# Gera o Generated.xcconfig com a versão do pubspec.yaml
flutter build ios --release --config-only --dart-define=IOS_PUSH_ENABLED=true

xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/ios/archive/Runner.xcarchive \
  archive CODE_SIGNING_ALLOWED=NO -quiet

# Grava as permissões no app do archive (assinatura local, descartável); a
# exportação assina de verdade por cima e mantém essas permissões.
APP=build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
codesign --force --deep --sign - "$APP"
codesign --force --sign - --entitlements ios/Runner/Runner.entitlements "$APP"

rm -rf build/ios/ipa
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa -exportOptionsPlist ios/ExportOptions.plist \
  -allowProvisioningUpdates

echo "\nIPA pronto em build/ios/ipa/ — enviar pelo Transporter."
