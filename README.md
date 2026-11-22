# NoScroll

Una app con dos pestanas: **Insta** (instagram.com sin Reels) y **Tube** (m.youtube.com sin Shorts).
CSS inyectado oculta las entradas al feed vertical, y el navigation delegate cancela cualquier
navegacion a `/reels/`, `/reel/` o `/shorts/`.

## Compilar

GitHub Actions lo hace en cada push (`.github/workflows/build.yml`): XcodeGen genera el
`.xcodeproj` desde `project.yml`, xcodebuild archiva sin firmar y sale `NoScroll.ipa`.

- **Artifact** del run: `NoScroll-ipa` (zip de GitHub, hay que descomprimir).
- **Release** con URL directa para SideStore: `git tag v2 && git push --tags`.

## Instalar

SideStore firma el `.ipa` al instalarlo. Caduca y hay que refrescar segun tu certificado.

## Mantenimiento

Lo unico que caduca de verdad son los selectores CSS, en `App/Sites.swift`.
Cuando Instagram o YouTube cambien el DOM, se arreglan ahi.
