#!/usr/bin/env bash
#
# Invoke the rdf-toolkit to convert an RDF file to another format
#
SCRIPT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P)"

if [ -f ${SCRIPT_DIR}/../lib/_functions.sh ] ; then
  # shellcheck source=../lib/_functions.sh
  source ${SCRIPT_DIR}/../lib/_functions.sh || exit $?
else # This else section is to trick IntelliJ Idea to actually load _functions.sh during editing
  source ../lib/_functions.sh || exit $?
fi

#
# Invoke the rdf-toolkit to convert an RDF file to another format
#
function convertRdfFileTo() {

  local -r sourceFormat="$1"  ; requireParameter sourceFormat || return $?
  local -r rdfFile="$2"       ; requireParameter rdfFile || return $?
  local -r targetFormat="$3"  ; requireParameter targetFormat || return $?

  logItem "Converting to ${targetFormat}" "$(logFileName "${rdfFile}")"

  local rdfFileNoExtension="${rdfFile/.rdf/}"
  rdfFileNoExtension="${rdfFileNoExtension/.ttl/}"
  rdfFileNoExtension="${rdfFileNoExtension/.jsonld/}"

  local targetFile="${rdfFileNoExtension}"

  case ${targetFormat} in
    rdf-xml)
      targetFile="${targetFile}.rdf"
      ;;
    json-ld)
      targetFile="${targetFile}.jsonld"
      ;;
    turtle)
      targetFile="${targetFile}.ttl"
      ;;
    *)
      error "Unsupported format ${targetFormat}"
      return 1
      ;;
  esac

  local rc=0
  local logfile ; logfile="$(mktempWithExtension convertRdfFile log)" || return $?

  java \
    --add-opens java.base/java.lang=ALL-UNNAMED \
    -Xmx1G \
    -Xms1G \
    -Dfile.encoding=UTF-8 \
    -cp "${SCRIPT_DIR}/../lib/javax.xml.bind.jar:${RDFTOOLKIT_JAR}" \
    org.edmcouncil.rdf_toolkit.SesameRdfFormatter \
    --source "${rdfFile}" \
    --source-format "${sourceFormat}" \
    --target "${targetFile}" \
    --target-format "${targetFormat}" \
    --inline-blank-nodes \
    --infer-base-iri \
    --use-dtd-subset \
    > "${logfile}" 2>&1
  rc=$?

  if ${GREP} -q "ERROR" "${logfile}"; then
    error "Found errors during conversion of$(logFileName "${rdfFile}") to \"${targetFormat}\":"
    cat "${logfile}"
    rc=1
  elif ${GREP} -q "WARNING" "${logfile}"; then
    warning "Found warnings during conversion of $(logFileName "${rdfFile}") to \"${targetFormat}\":"
    cat "${logfile}"
# else
#   log "Conversion of $(logFileName "${rdfFile}") to \"${targetFormat}\" was successful"
  fi

  rm "${logfile}"

  return ${rc}
}

function main() {

  convertRdfFileTo "$@"
  local -r rc=$?

  ((rc == 0)) && return 0
  warning "convertRdfFile.sh $@ returned ${rc}"

  return ${rc}
}

main "$@"
exit $?
