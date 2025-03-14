 #!/bin/bash
set -o nounset
set -o errexit

readonly script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

oc apply -k "${script_dir}/setup"
