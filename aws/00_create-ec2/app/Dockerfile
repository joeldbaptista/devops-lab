FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY main.py ./

RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser

ENTRYPOINT ["python", "main.py"]
CMD ["3"]
