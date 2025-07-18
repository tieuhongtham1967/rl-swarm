from rgym_exp.src.utils.reward_utils import *

class RGRewards:
    def __init__(self):
        self.stage = 0
        self.reward_fn = self.cumulative_reward
    
    def cumulative_reward(
        self, completions, answer, metadata, include_formatting=False
    ):
        if completions is None or not completions or not isinstance(completions, list):
            return [7] 
        
        if answer is None or not answer:
            # DEBUG: Thêm logging trước khi gọi len()
            print(f"DEBUG: answer is None/empty, completions type: {type(completions)}")
            print(f"DEBUG: completions value: {completions}")
            print(f"DEBUG: completions is None: {completions is None}")
            print(f"DEBUG: isinstance(completions, list): {isinstance(completions, list)}")
            
            try:
                completion_length = len(completions)
                print(f"DEBUG: len(completions) = {completion_length}")
                return [7] * completion_length
            except Exception as e:
                print(f"DEBUG: Error calling len(completions): {type(e).__name__}: {str(e)}")
                print(f"DEBUG: completions actual value: {repr(completions)}")
                raise e
        
        correctness = accuracy_reward(completions, answer, metadata, weight=1.0)
        if include_formatting:
            formatting = format_reward(completions, weight=0.1)
            cumulative = [sum(tup) for tup in zip(formatting, correctness)]
        else:
            cumulative = correctness
     
        scaled = [
            int(7 + min(max(score, 0.0), 1.0) * 10)  
            for score in cumulative
        ]
        return scaled
    
    def __call__(self, game_state):
        completions, answers, metadata = parse_game_state(game_state, self.stage)
        rewards = {}  # Key per agent
        for agent in completions:
            rewards[agent] = {}  # Will store a list per batch item
            for batch_id in completions[agent]:
                rewards[agent][batch_id] = []
                for node_idx, _ in enumerate(completions[agent][batch_id]):
                    rewards[agent][batch_id].append(
                        self.reward_fn(
                            completions[agent][batch_id][node_idx],
                            answers[agent][batch_id][node_idx],
                            metadata[agent][batch_id][node_idx],
                        )
                    )
        return rewards
