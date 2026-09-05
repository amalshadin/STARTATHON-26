from fastapi import FastAPI

app = FastAPI(
    title="HapticSync API",
    description="Backend API for The HapticSync stroke rehabilitation platform",
    version="0.1.0",
)


@app.get("/")
def root():
    return {
        "message": "HapticSync API is running",
        "version": "0.1.0"
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}