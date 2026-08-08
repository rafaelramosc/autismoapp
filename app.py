import os
import subprocess
import tarfile
import urllib.request
import openpyxl
import streamlit as st


@st.cache_resource
def install_and_get_julia():
    """Baixa e extrai os binários do Julia no diretório /tmp se ainda não existirem."""
    julia_bin = "/tmp/julia-1.10.0/bin/julia"

    if not os.path.exists(julia_bin):
        with st.spinner(
            "Configurando o ambiente Julia pela primeira vez (isso pode levar 1-2 minutos)..."
        ):
            url = "https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.0-linux-x86_64.tar.gz"
            tar_path = "/tmp/julia.tar.gz"

            # Download do Julia oficial
            urllib.request.urlretrieve(url, tar_path)

            # Extração
            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path="/tmp")

            # Remoção do arquivo compactado após extração
            if os.path.exists(tar_path):
                os.remove(tar_path)

    return julia_bin


st.title("Alocador de Terapias - Clínica de Autismo")

uploaded_file = st.file_uploader("Escolha a planilha de entrada (.xlsx)", type="xlsx")

if uploaded_file is not None:
    input_path = "instProjAutismo.xlsx"
    with open(input_path, "wb") as f:
        f.write(uploaded_file.read())
    st.success("Arquivo salvo como instProjAutismo.xlsx")

    try:
        wb = openpyxl.load_workbook(input_path, read_only=True)
        sheets = wb.sheetnames
        sheet_selected = st.selectbox("Selecione a aba (sheet):", sheets)
    except Exception as e:
        st.error(f"Erro ao ler as abas da planilha: {e}")
        sheet_selected = None

    if sheet_selected and st.button("Executar Modelo"):
        st.info(f"Executando modelo Julia na aba '{sheet_selected}'...")

        # Obtém o caminho absoluto do executável do Julia
        julia_executable = install_and_get_julia()

        # Garante o caminho correto para o script e arquivo de saída
        script_dir = os.path.dirname(os.path.abspath(__file__))
        julia_script = os.path.join(script_dir, "modeloAlocAutismo2_args.jl")

        julia_cmd = [
            julia_executable,
            julia_script,
            input_path,
            sheet_selected,
        ]

        # Executa o Julia
        result = subprocess.run(julia_cmd, capture_output=True, text=True)

        if result.returncode == 0:
            st.success("Modelo executado com sucesso.")
            output_path = os.path.join(
                script_dir, "instanciasProjAutismo", "outputSolution2.xlsx"
            )

            if os.path.exists(output_path):
                with open(output_path, "rb") as f:
                    st.download_button(
                        "Baixar Resultado (.xlsx)",
                        data=f,
                        file_name="outputSolution2.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
            else:
                st.error(
                    f"Arquivo de saída não encontrado no caminho: {output_path}"
                )
        else:
            st.error("Erro ao executar o modelo Julia.")
            st.code(result.stderr)
