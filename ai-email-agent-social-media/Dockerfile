FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DEFAULT_TIMEOUT=180 \
    PIP_RETRIES=10 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/root/.cache/huggingface \
    TRANSFORMERS_CACHE=/root/.cache/huggingface

WORKDIR /app

COPY requirements.txt requirements_agent2.txt ./
RUN python -m pip install --upgrade pip && \
    pip install --no-cache-dir --prefer-binary --retries 10 --timeout 180 -r requirements.txt && \
    pip install --no-cache-dir --prefer-binary --retries 10 --timeout 180 -r requirements_agent2.txt

COPY . .

EXPOSE 8003

CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8003"]
