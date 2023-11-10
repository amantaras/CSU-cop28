from promptflow import tool

#We return only the last 3 message for the context
@tool
def my_python_tool(chat_history: str) -> str:
 return chat_history[-3:]
