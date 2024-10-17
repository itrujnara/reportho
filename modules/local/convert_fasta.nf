process CONVERT_FASTA {
    tag "$input_file"
    label 'process_single'

    // THINGS ARE WRONG HERE, FIXME WHEN SEQERA CONTAINTAINERS START TO COOPERATE
    conda "conda-forge::python=3.12.0 conda-forge::biopython=1.84.0 conda-forge::requests=2.32.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-bc54124b36864a4af42a9db48b90a404b5869e7e:5258b8e5ba20587b7cbf3e942e973af5045a1e59-0' :
        'community.wave.seqera.io/library/biopython_python_requests:f428b20141d61c3b' }"

    input:
    tuple val(meta), path(input_file)

    output:
    tuple val(meta), path("*.fa"), emit: fasta
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: meta.id
    """
    clustal2fasta.py $input_file ${prefix}.fa

    cat <<- END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version | cut -d ' ' -f 2)
        Biopython: \$(pip show biopython | grep Version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fa

    cat <<- END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version | cut -d ' ' -f 2)
        Biopython: \$(pip show biopython | grep Version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
