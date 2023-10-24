from promptflow import tool

#@tool
#def my_python_tool(safety_result: str) -> str:
    # Access the suggested_action field
#    suggested_action = safety_result['suggested_action']

    # Return the suggested action
#    return suggested_action


@tool
def my_python_tool(safety_result: str) -> str:
       # Check if all values in 'action_by_category' are 'Accept'
    if all(value == 'Accept' for value in safety_result['action_by_category'].values()):
        return 'Accept'
    else:
        # Create a list of rejected categories
        rejected_categories = [category for category, action in safety_result['action_by_category'].items() if action == 'Reject']
        # Return a single string with all the rejected categories listed
        if rejected_categories:
            return f'Your message contains inappropriate content due to {", ".join(rejected_categories)}.'
        else:
            # Use a switch case to return personalized text for each category that does not have 'Accept'
            switcher = {
                'Hate': 'Your message contains hateful content.',
                'SelfHarm': 'Your message contains self-harm related content.',
                'Sexual': 'Your message contains sexual content.',
                'Violence': 'Your message contains violent content.'
            }
            for category, action in safety_result['action_by_category'].items():
                if action != 'Accept':
                    return switcher.get(category, 'Your message contains inappropriate content.')
            return 'Your message contains inappropriate content.'