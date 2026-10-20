#!/bin/sh
# Instala los hooks versionados del repo. Se ejecuta una vez después de clonar.
#
# .git/hooks/ no se sube a GitHub, así que los hooks viven en .githooks/ y se le
# dice a Git que los busque ahí.
set -e

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/post-commit .githooks/pre-push .githooks/post-push

# Git no tiene post-push: se emula con un alias que hace el push y, si ha ido bien
# (&&), lanza .githooks/post-push. Uso: git pushx (mismos argumentos que git push).
git config alias.pushx '!f() { git push "$@" && .githooks/post-push; }; f'

echo "✅ Hooks instalados (core.hooksPath = .githooks). Usa 'git pushx' para incluir el post-push."
