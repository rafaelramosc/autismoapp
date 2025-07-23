import streamlit as st
import subprocess
import os
import openpyxl

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
        julia_cmd = [
            "julia",
            "modeloAlocAutismo2_args.jl",
            input_path,
            sheet_selected
        ]
        result = subprocess.run(julia_cmd, capture_output=True, text=True)

        if result.returncode == 0:
            st.success("Modelo executado com sucesso.")
            output_path = "instanciasProjAutismo/outputSolution2.xlsx"
            if os.path.exists(output_path):
                with open(output_path, "rb") as f:
                    st.download_button("Baixar Resultado (.xlsx)",
                                       data=f,
                                       file_name="outputSolution2.xlsx",
                                       mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
            else:
                st.error("Arquivo de saída não encontrado.")
        else:
            st.error("Erro ao executar o modelo Julia.")
            st.text(result.stderr)