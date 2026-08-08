import os
import subprocess
import tarfile
import urllib.request
import openpyxl
import streamlit as st


@st.cache_resource
def install_and_get_julia():
    """Baixa e prepara o ambiente Julia no contêiner de execução."""
    julia_dir = "/tmp/julia-1.8.5"
    julia_bin = os.path.join(julia_dir, "bin", "julia")

    if not os.path.exists(julia_bin):
        with st.spinner("Configurando ambiente Julia (1ª vez)..."):
            url = "https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz"
            tar_path = "/tmp/julia.tar.gz"
            urllib.request.urlretrieve(url, tar_path)

            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path="/tmp")

            if os.path.exists(tar_path):
                os.remove(tar_path)

            # Instala apenas os pacotes necessários
            julia_pkgs = 'using Pkg; Pkg.add(["JuMP", "HiGHS", "XLSX"])'
            subprocess.run([julia_bin, "-e", julia_pkgs], check=True)

    return julia_bin


# Configuração básica da página
st.set_page_config(
    page_title="Alocador de Terapias", page_icon="🧩", layout="centered"
)

st.title("🧩 Alocador de Terapias")
st.write("Faça o upload da planilha e escolha a aba para executar o modelo.")

# 1. Seleção do Arquivo
uploaded_file = st.file_uploader("1. Selecione o arquivo (.xlsx)", type="xlsx")

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
        st.error(f"Erro ao ler abas da planilha: {e}")
        sheet_selected = None

    # 3. Botão de Execução
    if sheet_selected and st.button("🚀 Executar Alocação"):
        with st.spinner("Otimizando alocação... Por favor aguarde."):
            julia_bin = install_and_get_julia()
            script_path = os.path.join(
                os.path.dirname(os.path.abspath(__file__)),
                "modeloAlocAutismo2_args.jl",
            )

            # Executa o modelo Julia
            result = subprocess.run(
                [julia_bin, script_path, input_path, sheet_selected],
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                st.success("Alocação concluída com sucesso!")
                with open(input_path, "rb") as f:
                    st.download_button(
                        label="📥 Baixar Planilha Processada (.xlsx)",
                        data=f,
                        file_name=f"resultado_{sheet_selected}.xlsx",
                        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
            else:
                st.error("Erro na execução do modelo.")
                st.code(result.stderr)
