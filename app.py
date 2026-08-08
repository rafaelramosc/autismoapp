import os
import subprocess
import tarfile
import urllib.request
import openpyxl
import streamlit as st


@st.cache_resource
def install_and_get_julia():
    """Baixa o Julia 1.8.5 e instala os pacotes do Julia necessários (JuMP, HiGHS, XLSX)."""
    julia_dir = "/tmp/julia-1.8.5"
    julia_bin = os.path.join(julia_dir, "bin", "julia")

    if not os.path.exists(julia_bin):
        with st.spinner(
            "Configurando ambiente Julia e instalando solvers (isso ocorre apenas na 1ª execução)..."
        ):
            # Download do Julia 1.8.5 LTS
            url = "https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz"
            tar_path = "/tmp/julia.tar.gz"

            urllib.request.urlretrieve(url, tar_path)

            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path="/tmp")

            if os.path.exists(tar_path):
                os.remove(tar_path)

            # Instalação dos pacotes open-source do Julia
            julia_pkgs = 'using Pkg; Pkg.add(["JuMP", "HiGHS", "XLSX"])'
            subprocess.run([julia_bin, "-e", julia_pkgs], check=True)

    return julia_bin


# Interface do Streamlit
st.title("Alocador de Terapias - Clínica de Autismo")

# Upload do arquivo Excel de entrada
uploaded_file = st.file_uploader(
    "Escolha a planilha de entrada (.xlsx)", type="xlsx"
)

if uploaded_file is not None:
    input_path = "instProjAutismo.xlsx"

    # Salva o arquivo enviado localmente
    with open(input_path, "wb") as f:
        f.write(uploaded_file.read())
    st.success("Arquivo salvo como instProjAutismo.xlsx")

    # Leitura das abas da planilha
    try:
        wb = openpyxl.load_workbook(input_path, read_only=True)
        sheets = wb.sheetnames
        sheet_selected = st.selectbox("Selecione a aba (sheet):", sheets)
    except Exception as e:
        st.error(f"Erro ao ler as abas da planilha: {e}")
        sheet_selected = None

    # Botão de execução do modelo
    if sheet_selected and st.button("Executar Modelo"):
        st.info(f"Executando modelo Julia na aba '{sheet_selected}'...")

        # Obtém o caminho do binário do Julia
        julia_executable = install_and_get_julia()

        # Definição dos caminhos para o script .jl e arquivo de saída
        script_dir = os.path.dirname(os.path.abspath(__file__))
        julia_script = os.path.join(script_dir, "modeloAlocAutismo2_args.jl")

        julia_cmd = [
            julia_executable,
            julia_script,
            input_path,
            sheet_selected,
        ]

        # Execução do processo Julia
        result = subprocess.run(julia_cmd, capture_output=True, text=True)

        if result.returncode == 0:
            st.success("Modelo executado com sucesso.")

            # Caminho do arquivo de resultado
            output_path = os.path.join(
                script_dir, "instanciasProjAutismo", "outputSolution2.xlsx"
            )

            if os.path.exists(output_path):
                with open(output_path, "rb") as f:
                    st.download_button(
                        label="Baixar Resultado (.xlsx)",
                        data=f,
                        file_name="outputSolution2.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
            else:
                st.error(
                    f"Arquivo de saída não encontrado em: {output_path}"
                )
        else:
            st.error("Erro ao executar o modelo Julia.")
            st.code(result.stderr)
