# Lo cargan los hooks con ". .githooks/_python.sh": elige el Python del proyecto.
# Git no activa el entorno virtual al lanzar un hook, así que se busca a mano.
if [ -x .venv/bin/python ]; then
    PY=.venv/bin/python
else
    PY=python3
fi
