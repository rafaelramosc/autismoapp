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
        with st.spinner("Instalando o ambiente Julia no servidor..."):
            url = "https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz"
            tar_path = "/tmp/julia.tar.gz"

            urllib.request.urlretrieve(url, tar_path)

            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path="/tmp")

            if os.path.exists(tar_path):
                os.remove(tar_path)

    return julia_bin


def ensure_julia_packages(julia_bin):
    """Garante que JuMP, HiGHS e XLSX estejam instalados e prontos para uso."""
    # Testa se o JuMP já está funcional no ambiente
    check_cmd = [julia_bin, "-e", "using JuMP, HiGHS, XLSX"]
    check_res = subprocess.run(check_cmd, capture_output=True, text=True)

    if check_res.returncode != 0:
        with st.spinner(
            "Instalando bibliotecas do Julia (JuMP, HiGHS, XLSX)... Isso pode levar 1 a 2 minutos."
        ):
            install_cmd = [
                julia_bin,
                "-e",
                'using Pkg; Pkg.add(["JuMP", "HiGHS", "XLSX"])',
            ]
            subprocess.run(install_cmd, check=True)


# Configuração do App Streamlit
st.set_page_config(
    page_title="Alocador de Terapias", page_icon="🧩", layout="centered"
)

st.title("🧩 Alocador de Terapias - Clínica de Autismo")
st.write("Envie a planilha em formato `.xlsx` e escolha a aba para otimização.")

# 1. Upload da Planilha
uploaded_file = st.file_uploader(
    "1. Selecione a planilha de entrada (.xlsx)", type="xlsx"
)

if uploaded_file is not None:
    input_path = "instProjAutismo.xlsx"

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

    # 3. Execução
    if sheet_selected and st.button("🚀 Executar Alocação"):
        julia_bin = get_julia_executable()

        # Garante a existência dos pacotes antes do subprocess
        ensure_julia_packages(julia_bin)

        script_path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "modeloAlocAutismo2_args.jl",
        )

        with st.spinner(
            f"Executando otimização na aba '{sheet_selected}'..."
        ):
            result = subprocess.run(
                [julia_bin, script_path, input_path, sheet_selected],
                capture_output=True,
                text=True,
            )

        if result.returncode == 0:
            st.success("Alocação concluída com sucesso!")
            if os.path.exists(input_path):
                with open(input_path, "rb") as f:
                    st.download_button(
                        label="📥 Baixar Resultado (.xlsx)",
                        data=f,
                        file_name=f"resultado_{sheet_selected}.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
            else:
                st.error("Arquivo de saída não encontrado.")
        else:
            st.error("Erro durante a execução do script Julia:")
            st.code(result.stderr)
