from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import random

app = FastAPI(title="DGS AI Question Generator")

class QuestionSchema(BaseModel):
    topic_id: int
    question_text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    correct_option: str
    solution: str

# Mock AI Generation Logic
@app.get("/generate-question", response_model=QuestionSchema)
async def generate_question(topic_id: int):
    # This would normally call an AI API like OpenAI or Gemini
    # For now, it returns a slightly randomized math question
    a = random.randint(1, 100)
    b = random.randint(1, 100)
    result = a + b
    
    return {
        "topic_id": topic_id,
        "question_text": f"{a} + {b} işleminin sonucu kaçtır?",
        "option_a": f"{result - 1}",
        "option_b": f"{result}",
        "option_c": f"{result + 5}",
        "option_d": f"{result + 10}",
        "correct_option": "b",
        "solution": f"{a} ve {b} toplandığında {result} elde edilir."
    }

@app.get("/")
def read_root():
    return {"status": "AI Soru Kaynağı Aktif"}
