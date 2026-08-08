import os
import subprocess
import tarfile
import urllib.request
import openpyxl
import streamlit as st


def get_julia_executable():
    """Baixa e extrai os binários do Julia 1.8.5 se ainda não existirem."""
    julia_dir = "/tmp/julia-1.8.5"
    julia_bin = os.path.join(julia_dir, "bin", "julia")

    if not os.path.exists(julia_bin):
        with st.spinner(
            "Configurando ambiente Julia no servidor... (Apenas no 1º uso)"
        ):
            url = "https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz"
            tar_path = "/tmp/julia.tar.gz"

            urllib.request.urlretrieve(url, tar_path)

            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path="/tmp")

            if os.path.exists(tar_path):
                os.remove(tar_path)

    return julia_bin


def ensure_julia_packages(julia_bin):
    """Garante que JuMP, HiGHS e XLSX estejam instalados e prontos."""
    check_cmd = [julia_bin, "-e", "using JuMP, HiGHS, XLSX"]
    check_res = subprocess.run(check_cmd, capture_output=True, text=True)

    if check_res.returncode != 0:
        with st.spinner(
            "Instalando pacotes do Julia (JuMP, HiGHS, XLSX)... Isso pode levar de 1 a 2 minutos na primeira execução."
        ):
            install_cmd = [
                julia_bin,
                "-e",
                'using Pkg; Pkg.add(["JuMP", "HiGHS", "XLSX"])',
            ]
            subprocess.run(install_cmd, check=True)


# Interface do Streamlit
st.set_page_config(
    page_title="Alocador de Terapias - Mestrado", page_icon="🧩", layout="centered"
)

st.title("🧩 Alocador de Terapias - Clínica de Autismo")
st.write(
    "Selecione o arquivo Excel de entrada (.xlsx) e escolha a aba da instância para otimizar."
)

# 1. Upload do Arquivo
uploaded_file = st.file_uploader(
    "1. Selecione a planilha de entrada (.xlsx)", type="xlsx"
)

if uploaded_file is not None:
    input_path = "instProjAutismo.xlsx"

    # Salva localmente no container
    with open(input_path, "wb") as f:
        f.write(uploaded_file.read())

    # 2. Seleção da Aba
    try:
        wb = openpyxl.load_workbook(input_path, read_only=True)
        sheet_selected = st.selectbox(
            "2. Selecione a aba (instância):", wb.sheetnames
        )
    except Exception as e:
        st.error(f"Erro ao ler as abas da planilha: {e}")
        sheet_selected = None

    # 3. Botão de Execução
    if sheet_selected and st.button("🚀 Executar Alocação (HiGHS)"):
        julia_bin = get_julia_executable()
        ensure_julia_packages(julia_bin)

        script_dir = os.path.dirname(os.path.abspath(__file__))
        script_path = os.path.join(script_dir, "modeloAlocAutismo2_args.jl")

        with st.spinner(
            f"Otimizando a aba '{sheet_selected}' com o solver HiGHS..."
        ):
            result = subprocess.run(
                [julia_bin, script_path, input_path, sheet_selected],
                capture_output=True,
                text=True,
            )

        if result.returncode == 0:
            st.success("Otimização concluída com sucesso!")
            if os.path.exists(input_path):
                with open(input_path, "rb") as f:
                    st.download_button(
                        label="📥 Baixar Resultado (.xlsx)",
                        data=f,
                        file_name=f"resultado_{sheet_selected}.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
            else:
                st.error("Arquivo de resultado não encontrado.")
        else:
            st.error("Erro durante a execução do script Julia:")
            st.code(result.stderr)
