@echo off
echo Ativando ambiente virtual (se aplicável)...
REM call .venv\Scripts\activate

echo Instalando dependências...
pip install -r requirements.txt

echo Iniciando Streamlit...
streamlit run app.py
pause