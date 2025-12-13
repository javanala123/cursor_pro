FROM python:3.10-slim

WORKDIR /app

COPY requirements_parallel.txt /app/
RUN pip install --no-cache-dir -r requirements_parallel.txt

COPY . /app

# Prometheus metrics port
ENV PROMETHEUS_PORT=8001

EXPOSE 5000 8001

CMD ["python", "run_parallel_backtest.py", "--mode", "quick", "--workers", "4"]


