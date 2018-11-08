#! /bin/bash

: "${AUTHOR:=EnterAuthorName}"
: "${EMAIL:=EnterAuthorEmail}"
: "${PYTHON_VERSION:=3.6}"
: "${PKG_VERSION:=0.1.0}"

###############################################################################

MAIN_DIR=${1:?"Specify a package name"}
SOURCE_DIR="${2:-$1}"
: "${DATA_DIR:=data}"
: "${DOCKER_DIR:=docker}"
: "${DOCS_DIR:=docs}"
: "${FILE_SEP:=/}"
: "${NOTEBOOK_DIR:=notebooks}"
: "${TEST_DIR:=tests}"
: "${WHEEL_DIR:=wheels}"

if [[ ${SOURCE_DIR} == *-* ]]; then
    msg="\n\nBy Python convention the source directory name may not contain "
    msg+="hyphens.\n"
    msg+="This script uses the package name (mandatory first argument) for "
    msg+="the source directory name if a second argument is not provided.\n"
    msg+="\npypackage_generator.sh <package_name> <source_directory>\n"
    msg+="\n\nPlease supply a source directory name without hyphens."
    printf %b "${msg}"
    exit 0
fi

YEAR=`date +%Y`

SUB_DIRECTORIES=(${DATA_DIR} \
                 ${DOCKER_DIR} \
                 ${DOCS_DIR} \
                 ${NOTEBOOK_DIR} \
                 ${SOURCE_DIR} \
                 ${WHEEL_DIR})

PY_SHEBANG="#! /usr/bin/env python3"
PY_ENCODING="# -*- coding: utf-8 -*-"

SRC_PATH="${MAIN_DIR}${FILE_SEP}${SOURCE_DIR}${FILE_SEP}"


conftest() {
    printf "%s\n" \
        "${PY_SHEBANG}" \
        "${PY_ENCODING}" \
        '""" Test Configuration File' \
        '"""' \
        "import pytest" \
        "" \
        > "${SRC_PATH}${FILE_SEP}${TEST_DIR}${FILE_SEP}conftest.py"
}


constructor_pkg() {
    printf "%s\n" \
        "${PY_SHEBANG}" \
        "${PY_ENCODING}" \
        "" \
        "from pkg_resources import get_distribution, DistributionNotFound" \
        "import os.path as osp" \
        "" \
        "# from . import cli" \
        "# from . import EnterModuleNameHere" \
        "" \
        "__version__ = '0.1.0'" \
        "" \
        "try:" \
        "    _dist = get_distribution('${MAIN_DIR}')" \
        "    dist_loc = osp.normcase(_dist.location)" \
        "    here = osp.normcase(__file__)" \
        "    if not here.startswith(osp.join(dist_loc, '${MAIN_DIR}')):" \
        "        raise DistributionNotFound" \
        "except DistributionNotFound:" \
        "    __version__ = 'Please install this project with setup.py'" \
        "else:" \
        "    __version__ = _dist.version" \
        > "${SRC_PATH}__init__.py"
}


constructor_test() {
    printf "%s\n" \
        "${PY_SHEBANG}" \
        "${PY_ENCODING}" \
        > "${SRC_PATH}${FILE_SEP}${TEST_DIR}${FILE_SEP}__init__.py"
}


directories() {
    # Main directory
    mkdir "${MAIN_DIR}"
    # Subdirectories
    for dir in "${SUB_DIRECTORIES[@]}"; do
        mkdir "${MAIN_DIR}${FILE_SEP}${dir}"
    done
    # Test directory
    mkdir "${MAIN_DIR}${FILE_SEP}${SOURCE_DIR}${FILE_SEP}${TEST_DIR}"
}


docker_compose() {
    printf "%s\n" \
        "version: '3'" \
        "" \
        "services:" \
        "" \
        "  nginx:" \
        "    container_name: ${MAIN_DIR}_nginx" \
        "    image: nginx:alpine" \
        "    ports:" \
        "      - 8080:80" \
        "    restart: always" \
        "    volumes:" \
        "      - ../docs/_build/html:/usr/share/nginx/html:ro" \
        "" \
        "  postgres:" \
        "    container_name: ${MAIN_DIR}_postgres" \
        "    image: postgres:alpine" \
        "    environment:" \
        "      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}" \
        "      POSTGRES_DB: \${POSTGRES_DB}" \
        "      POSTGRES_USER: \${POSTGRES_USER}" \
        "    ports:" \
        "      - 5432:5432" \
        "    restart: always" \
        "    volumes:" \
        "      - ${MAIN_DIR}-db:/var/lib/postgresql/data" \
        "" \
        "  pgadmin:" \
        "    container_name: ${MAIN_DIR}_pgadmin" \
        "    image: dpage/pgadmin4" \
        "    environment:" \
        "      PGADMIN_DEFAULT_EMAIL: \${PGADMIN_DEFAULT_EMAIL}" \
        "      PGADMIN_DEFAULT_PASSWORD: \${PGADMIN_DEFAULT_PASSWORD}" \
        "    external_links:" \
        "      - ${MAIN_DIR}_postgres:${MAIN_DIR}_postgres" \
        "    ports:" \
        "      - 5000:80" \
        "" \
        "  python:" \
        "    container_name: ${MAIN_DIR}_python" \
        "    build:" \
        "      context: .." \
        "      dockerfile: docker/python-Dockerfile" \
        "    image: ${MAIN_DIR}_python" \
        "    restart: always" \
        "    tty: true" \
        "    volumes:" \
        "      - ..:/usr/src/${MAIN_DIR}" \
        "" \
        "volumes:" \
        "  ${MAIN_DIR}-db:" \
        "" \
        > "${MAIN_DIR}${FILE_SEP}${DOCKER_DIR}${FILE_SEP}docker-compose.yml"
}


docker_python() {
    printf "%b\n" \
        "FROM python:3.6-alpine" \
        "" \
        "WORKDIR /usr/src/${MAIN_DIR}" \
        "" \
        "COPY . ." \
        "" \
        "RUN apk add --update \\\\" \
        "\t\talpine-sdk \\\\" \
        "\t\tbash \\\\" \
        "\t&& pip3 install --upgrade pip \\\\" \
        "\t&& pip3 install --no-cache-dir -r requirements.txt \\\\" \
        "\t&& pip3 install -e .[docs,notebook,test]" \
        "" \
        "CMD [ \"/bin/bash\" ]" \
        "" \
        > "${MAIN_DIR}${FILE_SEP}${DOCKER_DIR}${FILE_SEP}python-Dockerfile"
}


docker_tensorflow() {
    printf "%b\n" \
        "FROM python:3.6" \
        "" \
        "WORKDIR /usr/src/${MAIN_DIR}" \
        "" \
        "COPY . ." \
        "" \
        "RUN cd /opt \\\\" \
        "\t&& apt-get update \\\\" \
        "\t&& apt-get install -y \\\\" \
        "\t\tprotobuf-compiler \\\\" \
        "\t&& rm -rf /var/lib/apt/lists/* \\\\" \
        "\t&& git clone \\\\" \
        "\t\t--branch master \\\\" \
        "\t\t--single-branch \\\\" \
        "\t\t--depth 1 \\\\" \
        "\t\thttps://github.com/tensorflow/models.git \\\\" \
        "\t&& cd /opt/models/research \\\\" \
        "\t&& protoc object_detection/protos/*.proto --python_out=. \\\\" \
        "\t&& cd /usr/src/${MAIN_DIR} \\\\" \
        "\t&& pip install --upgrade pip \\\\" \
        "\t&& pip install --no-cache-dir -r requirements.txt \\\\" \
        "\t&& pip install -e .[docs,notebook,tf-cpu,test]" \
        "" \
        "ENV PYTHONPATH \$PYTHONPATH:/opt/models/research:/opt/models/research/slim:/opt/models/research/object_detection" \
        "" \
        "CMD [ \"/bin/bash\" ]" \
        > "${MAIN_DIR}${FILE_SEP}${DOCKER_DIR}${FILE_SEP}tensorflow-Dockerfile"
}


envfile(){
    printf "%s\n" \
        "# PGAdmin" \
        "export PGADMIN_DEFAULT_EMAIL=enter_user@${MAIN_DIR}.com" \
        "export PGADMIN_DEFAULT_PASSWORD=enter_password" \
        "" \
        "# Postgres" \
        "export POSTGRES_PASSWORD=enter_password" \
        "export POSTGRES_DB=${MAIN_DIR}" \
        "export POSTGRES_USER=enter_user" \
        "" \
        > "${MAIN_DIR}${FILE_SEP}envfile"
}


git_attributes() {
    printf "%s\n" \
        "*.ipynb    filter=jupyter_clear_output" \
        > "${MAIN_DIR}${FILE_SEP}.gitattributes"
}


git_config() {
    # Setup Git to ignore Jupyter Notebook Outputs
    printf "%s\n" \
        "[filter \"jupyter_clear_output\"]" \
        "    clean = \"jupyter nbconvert --stdin --stdout \ " \
        "             --log-level=ERROR --to notebook \ " \
        "             --ClearOutputPreprocessor.enabled=True\"" \
        "    smudge = cat" \
        "    required = true" \
        > "${MAIN_DIR}${FILE_SEP}.gitconfig"
}


git_ignore() {
    printf "%s\n" \
        "# Compiled source" \
        "build${FILE_SEP}*" \
        "*.com" \
        "dist${FILE_SEP}*" \
        "*.egg-info${FILE_SEP}*" \
        "*.class" \
        "*.dll" \
        "*.exe" \
        "*.o" \
        "*.pdf" \
        "*.pyc" \
        "*.so" \
        "" \
        "# Ipython Files" \
        "${NOTEBOOK_DIR}${FILE_SEP}.ipynb_checkpoints${FILE_SEP}*" \
        "" \
        "# Logs and databases" \
        "*.log" \
        "*make.bat" \
        "*.sql" \
        "*.sqlite" \
        "" \
        "# OS generated files" \
        "envfile" \
        ".DS_Store" \
        ".DS_store?" \
        "._*" \
        ".Spotlight-V100" \
        ".Trashes" \
        "ehthumbs.db" \
        "Thumbs.db" \
        "" \
        "# Packages" \
        "*.7z" \
        "*.dmg" \
        "*.gz" \
        "*.iso" \
        "*.jar" \
        "*.rar" \
        "*.tar" \
        "*.zip" \
        "" \
        "# Profile files" \
        "*.coverage" \
        "*.profile" \
        "" \
        "# Project files" \
        "source_venv.sh" \
        "*wheels" \
        "" \
        "# PyCharm files" \
        ".idea${FILE_SEP}*" \
        "${MAIN_DIR}${FILE_SEP}.idea${FILE_SEP}*" \
        "" \
        "# pytest files" \
        ".cache${FILE_SEP}*" \
        "" \
        "# Raw Data" \
        "${DATA_DIR}${FILE_SEP}*" \
        "" \
        "# Sphinx files" \
        "docs/_build/*" \
        "docs/_static/*" \
        "docs/_templates/*" \
        "docs/Makefile" \
        > "${MAIN_DIR}${FILE_SEP}.gitignore"
}


git_init() {
    cd ${MAIN_DIR}
    git init
    git add --all
    git commit -m "Initial Commit"
}


license() {
    printf "%s\n" \
        "Copyright (c) ${YEAR}, ${AUTHOR}." \
        "All rights reserved." \
        "" \
        "Redistribution and use in source and binary forms, with or without" \
        "modification, are permitted provided that the following conditions are met:" \
        "" \
        "* Redistributions of source code must retain the above copyright notice, this" \
        "  list of conditions and the following disclaimer." \
        "" \
        "* Redistributions in binary form must reproduce the above copyright notice," \
        "  this list of conditions and the following disclaimer in the documentation" \
        "  and/or other materials provided with the distribution." \
        "" \
        "* Neither the name of the ${MAIN_DIR} Developers nor the names of any" \
        "  contributors may be used to endorse or promote products derived from this" \
        "  software without specific prior written permission." \
        "" \
        "THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\"" \
        "AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE" \
        "IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE" \
        "DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR" \
        "ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES" \
        "(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;" \
        "LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON" \
        "ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT" \
        "(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS" \
        "SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE." \
        > "${MAIN_DIR}${FILE_SEP}LICENSE.txt"
}


makefile() {
    printf "%b\n" \
        "PROJECT=${MAIN_DIR}" \
        "ifeq (\"\$(shell uname -s)\", \"Linux*\")" \
        "\tBROWSER=/usr/bin/firefox" \
        "else" \
        "\tBROWSER=open" \
        "endif" \
        "MOUNT_DIR=\$(shell pwd)" \
        "MODELS=/opt/models" \
        "PORT:=\$(shell awk -v min=16384 -v max=32768 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')" \
        "SRC_DIR=/usr/src/${SOURCE_DIR}" \
        "USER=\$(shell echo \$\${USER%%@*})" \
        "VERSION=\$(shell echo \$(shell cat ${SOURCE_DIR}/__init__.py | \\\\" \
        "\t\t\tgrep \"^__version__\" | \\\\" \
        "\t\t\tcut -d = -f 2))" \
        "" \
        "include envfile" \
        ".PHONY: docs upgrade-packages" \
        "" \
        "deploy: docker-up" \
        "\tdocker container exec \$(PROJECT)_python \\\\" \
        "\t\tpip3 wheel --wheel-dir=wheels ." \
        "\tgit tag -a v\$(VERSION) -m \"Version \$(VERSION)\"" \
        "\t@echo" \
        "\t@echo" \
        "\t@echo Enter the following to push this tag to the repository:" \
        "\t@echo git push origin v\$(VERSION)" \
        "" \
        "docker-down:" \
        "\tdocker-compose -f docker/docker-compose.yml down" \
        "" \
        "docker-rebuild: setup.py" \
        "\tdocker-compose -f docker/docker-compose.yml up -d --build" \
        "" \
        "docker-up:" \
        "\tdocker-compose -f docker/docker-compose.yml up -d" \
        "" \
        "docs: docker-up" \
        "\tdocker container exec \$(PROJECT)_python \\\\" \
        "\t\t/bin/bash -c \"pip install -e . && cd docs && make html\"" \
        "\t\${BROWSER} http://localhost:8080\n" \
        "" \
        "docs-init: docker-up" \
        "\trm -rf docs/*" \
        "\tdocker container exec \$(PROJECT)_python \\\\" \
        "\t\t/bin/bash -c \\\\" \
        "\t\t\t\"cd docs \\\\" \
        "\t\t\t && sphinx-quickstart -q \\\\" \
        "\t\t\t\t-p \$(PROJECT) \\\\" \
        "\t\t\t\t-a \"${AUTHOR}\" \\\\" \
        "\t\t\t\t-v \$(VERSION) \\\\" \
        "\t\t\t\t--ext-autodoc \\\\" \
        "\t\t\t\t--ext-viewcode \\\\" \
        "\t\t\t\t--makefile \\\\" \
        "\t\t\t\t--no-batchfile\"" \
        "\tdocker-compose -f docker/docker-compose.yml restart nginx" \
        "ifeq (\"\$(shell git remote)\", \"origin\")" \
        "\tgit fetch" \
        "\tgit checkout origin/master -- docs/" \
        "else" \
        "\tdocker container run --rm \\\\" \
        "\t\t-v \`pwd\`:/usr/src/\$(PROJECT) \\\\" \
        "\t\t-w /usr/src/\$(PROJECT)/docs \\\\" \
        "\t\tubuntu \\\\" \
        "\t\t/bin/bash -c \\\\" \
        "\t\t\t\"sed -i -e 's/# import os/import os/g' conf.py \\\\" \
        "\t\t\t && sed -i -e 's/# import sys/import sys/g' conf.py \\\\" \
        "\t\t\t && sed -i \\\\\"/# sys.path.insert(0, os.path.abspath('.'))/d\\\\\" \\\\" \
        "\t\t\t\tconf.py \\\\" \
        "\t\t\t && sed -i -e \\\\\"/import sys/a \\\\" \
        "\t\t\t\tsys.path.insert(0, os.path.abspath('../${SOURCE_DIR}')) \\\\" \
        "\t\t\t\t\\\\n\\\\nfrom ${SOURCE_DIR} import __version__\\\\\" \\\\" \
        "\t\t\t\tconf.py \\\\" \
        "\t\t\t && sed -i -e \\\\\"s/version = '0.1.0'/version = __version__/g\\\\\" \\\\" \
        "\t\t\t\tconf.py \\\\" \
        "\t\t\t && sed -i -e \\\\\"s/release = '0.1.0'/release = __version__/g\\\\\" \\\\" \
        "\t\t\t\tconf.py \\\\" \
        "\t\t\t && sed -i -e \\\\\"s/alabaster/sphinx_rtd_theme/g\\\\\" \\\\" \
        "\t\t\t\tconf.py \\\\" \
        "\t\t\t && sed -i \\\\\"/   :caption: Contents:/a \\\\" \
        "\t\t\t\t\\\\\\\\\\\\\\\\\\\\n   package\\\\\" \\\\" \
        "\t\t\t\tindex.rst\"" \
        "\tprintf \"%s\\\\n\" \\\\" \
        "\t\t\"Package Modules\" \\\\" \
        "\t\t\"===============\" \\\\" \
        "\t\t\"\" \\\\" \
        "\t\t\".. toctree::\" \\\\" \
        "\t\t\"    :maxdepth: 2\" \\\\" \
        "\t\t\"\" \\\\" \
        "\t\t\"cli\" \\\\" \
        "\t\t\"---\" \\\\" \
        "\t\t\".. automodule:: cli\" \\\\" \
        "\t\t\"    :members:\" \\\\" \
        "\t\t\"    :show-inheritance:\" \\\\" \
        "\t\t\"    :synopsis: Package commandline interface calls.\" \\\\" \
        "\t\t\"\" \\\\" \
        "\t> \"docs/package.rst\"" \
        "endif" \
        "" \
        "docs-view: docker-up" \
        "\t\${BROWSER} http://localhost:8080" \
        "" \
        "ipython: docker-up" \
        "\tdocker container exec -it \$(PROJECT)_python ipython" \
        "" \
        "notebook: notebook-server" \
        "\tsleep 0.5" \
        "\t\${BROWSER} \$\$(docker container exec \\\\" \
        "\t\t\$(USER)_notebook_\$(PORT) \\\\" \
        "\t\tjupyter notebook list | grep -o '^http\S*')" \
        "" \
        "notebook-remove:" \
        "\tdocker container rm -f \$\$(docker container ls -f name=\$(USER)_notebook -q)" \
        "" \
        "notebook-server:" \
        "\tdocker container run -d --rm \\\\" \
        "\t\t--name \$(USER)_notebook_\$(PORT) \\\\" \
        "\t\t-p \$(PORT):\$(PORT) \\\\" \
        "\t\t\$(PROJECT)_python \\\\" \
        "\t\t/bin/bash -c \"jupyter notebook \\\\" \
        "\t\t\t\t--allow-root \\\\" \
        "\t\t\t\t--ip=0.0.0.0 \\\\" \
        "\t\t\t\t--port=\$(PORT)\"" \
        "" \
        "pgadmin: docker-up" \
        "\t\${BROWSER} http://localhost:5000" \
        "" \
        "psql: docker-up" \
        "\tdocker container exec -it \$(PROJECT)_postgres \\\\" \
        "\t\tpsql -U \${POSTGRES_USER} \$(PROJECT)" \
        "" \
        "tensorflow:" \
        "\tdocker container run --rm \\\\" \
        "\t\t-v \`pwd\`:/usr/src/\$(PROJECT) \\\\" \
        "\t\t-w /usr/src/\$(PROJECT) \\\\" \
        "\t\tubuntu \\\\" \
        "\t\t/bin/bash -c \\\\" \
        "\t\t\t\"sed -i -e 's/python-Dockerfile/tensorflow-Dockerfile/g' \\\\" \
        "\t\t\t\tdocker/docker-compose.yml \\\\" \
        "\t\t\t && sed -i -e \\\\\"/'notebook': \['jupyter'\],/a \\\\" \
        "\t\t\t\t\\\\ \\\\ \\\\ \\\\ \\\\ \\\\ \\\\ \\\\ 'tf-cpu': ['tensorflow'],\\\\" \
        "\t\t\t\t\\\\n\\\\ \\\\ \\\\ \\\\ \\\\ \\\\ \\\\ \\\\ 'tf-gpu': ['tensorflow-gpu'],\\\\\" \\\\" \
        "\t\t\t\tsetup.py\"" \
        "" \
        "tensorflow-models: tensorflow docker-rebuild" \
        "ifneq (\$(wildcard \${MODELS}), )" \
        "\techo \"Updating TensorFlow Models Repository\"" \
        "\tcd \${MODELS} \\\\" \
        "\t&& git checkout master \\\\" \
        "\t&& git pull" \
        "\tcd \${MOUNT_DIR}" \
        "else" \
        "\techo \"Cloning TensorFlow Models Repository to \${MODELS}\"" \
        "\tmkdir -p \${MODELS}" \
        "\tgit clone https://github.com/tensorflow/models.git \${MODELS}" \
        "endif" \
        "" \
        "test: docker-up" \
        "\tdocker container exec \$(PROJECT)_python \\\\" \
        "\t\t/bin/bash -c \"py.test\\\\" \
        "\t\t\t\t--basetemp=pytest \\\\" \
        "\t\t\t\t--doctest-modules \\\\" \
        "\t\t\t\t--ff \\\\" \
        "\t\t\t\t--pep8 \\\\" \
        "\t\t\t\t-r all \\\\" \
        "\t\t\t\t-vvv\"" \
        "" \
        "upgrade-packages: docker-up" \
        "\tdocker container exec \$(PROJECT)_python \\\\" \
        "\t\t/bin/bash -c \\\\" \
        "\t\t\t\"pip3 install -U pip \\\\" \
        "\t\t\t && pip3 freeze | \\\\" \
        "\t\t\t\tgrep -v \$(PROJECT) | \\\\" \
        "\t\t\t\tcut -d = -f 1 > requirements.txt \\\\" \
        "\t\t\t && pip3 install -U -r requirements.txt \\\\" \
        "\t\t\t && pip3 freeze > requirements.txt \\\\" \
        "\t\t\t && sed -i -e '/^-e/d' requirements.txt\"" \
        > "${MAIN_DIR}${FILE_SEP}Makefile"
}


manifest() {
    printf "%s\n" \
        "include LICENSE.txt" \
        > "${MAIN_DIR}${FILE_SEP}MANIFEST.in"
}


readme() {
    printf "%s\n" \
        "# PGAdmin Setup" \
        "1. From the main directory call \`make pgadmin\`" \
        "    - The default browser will open to \`localhost:5000\`" \
        "1. Enter the **PGAdmin** default user and password." \
        "    - These variable are set in the \`envfile\`." \
        "1. Click \`Add New Server\`." \
        "    - General Name: Enter the <project_name>" \
        "    - Connection Host: Enter <project_name>_postgres" \
        "    - Connection Username and Password: Enter **Postgres** username and password" \
        "      from the \`envfile\`." \
        "" \
        > "${MAIN_DIR}${FILE_SEP}README.md"
}


requirements() {
    touch "${MAIN_DIR}${FILE_SEP}requirements.txt"
}


setup() {
    printf "%s\n" \
        "#!/usr/bin/env python3" \
        "# -*- coding: utf-8 -*-" \
        "" \
        "from codecs import open" \
        "import os.path as osp" \
        "import re" \
        "" \
        "from setuptools import setup, find_packages" \
        "" \
        "" \
        "with open('${SOURCE_DIR}${FILE_SEP}__init__.py', 'r') as fd:" \
        "    version = re.search(r'^__version__\s*=\s*[\'\"]([^\'\"]*)[\'\"]'," \
        "                        fd.read(), re.MULTILINE).group(1)" \
        "" \
        "here = osp.abspath(osp.dirname(__file__))" \
        "with open(osp.join(here, 'README.md'), encoding='utf-8') as f:" \
        "    long_description = f.read()" \
        "" \
        "setup(" \
        "    name='${MAIN_DIR}'," \
        "    version=version," \
        "    description='Modules related to EnterDescriptionHere'," \
        "    author='${AUTHOR}'," \
        "    author_email='${EMAIL}'," \
        "    license='BSD'," \
        "    classifiers=[" \
        "        'Development Status :: 1 - Planning'," \
        "        'Environment :: Console'," \
        "        'Intended Audience :: Developers'," \
        "        'License :: OSI Approved'," \
        "        'Natural Language :: English'," \
        "        'Operating System :: OS Independent'," \
        "        'Programming Language :: Python :: ${PYTHON_VERSION%%.*}'," \
        "        'Programming Language :: Python :: ${PYTHON_VERSION}'," \
        "        'Topic :: Software Development :: Build Tools'," \
        "        ]," \
        "    keywords='EnterKeywordsHere'," \
        "    packages=find_packages(exclude=[" \
        "        'data'," \
        "        'docker'," \
        "        'docs'," \
        "        'notebooks'," \
        "        'wheels'," \
        "        '*tests'," \
        "        ]" \
        "    )," \
        "    install_requires=[" \
        "        ]," \
        "    extras_require={" \
        "        'docs': ['sphinx', 'sphinx_rtd_theme']," \
        "        'notebook': ['jupyter']," \
        "        'test': ['pytest', 'pytest-pep8']," \
        "    }," \
        "    package_dir={'${MAIN_DIR}': '${SOURCE_DIR}'}," \
        "    include_package_data=True," \
        "    entry_points={" \
        "        'console_scripts': [" \
        "            # '<EnterCommandName>=${SOURCE_DIR}.cli:<EnterFunction>'," \
        "        ]" \
        "    }" \
        ")" \
        "" \
        "" \
        "if __name__ == '__main__':" \
        "    pass" \
        > "${MAIN_DIR}${FILE_SEP}setup.py"
}


directories
conftest
constructor_pkg
constructor_test
docker_compose
docker_python
docker_tensorflow
envfile
git_attributes
git_config
git_ignore
license
makefile
manifest
readme
requirements
setup
git_init
