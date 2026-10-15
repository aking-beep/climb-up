# The CLIMB UP records service. Standard library only: no pip install.
#   docker build -t climbup-records -f server/Dockerfile .
FROM python:3.13-slim
RUN useradd --system --uid 10001 --home /app records && mkdir -p /data /backups && chown records /data /backups
WORKDIR /app
COPY server/__init__.py server/__init__.py
COPY server/records_service server/records_service
RUN rm -rf server/records_service/tests server/records_service/__pycache__
USER records
ENV RECORDS_DB=/data/records.sqlite RECORDS_PORT=8080 RECORDS_BIND=0.0.0.0 PYTHONUNBUFFERED=1
EXPOSE 8080
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python3 -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=4).status == 200 else 1)"
CMD ["python3", "-m", "server.records_service.service"]
