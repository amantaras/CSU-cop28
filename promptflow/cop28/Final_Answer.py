from promptflow import tool

@tool
def my_python_tool(safety_result: str, llm_answer=None) -> str:
  if safety_result== "Accept":
    return llm_answer
  else:
    return safety_result