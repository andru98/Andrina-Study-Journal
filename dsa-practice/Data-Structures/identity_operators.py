list_1 = []
list_2 = []

if list_1 is list_2:
    print("both are referring to the same object")
else:
    print("both are not referring to the same object")

list_3 = list_1

if list_3 is not list_1:
    print("both are not referring to the same object")
else :
    print("both are referring to the same object")

# anagrams (# concoet of defaultdict(int, list, set groupoing)

'''
default dict is a collection module of python which is a subclass of the dictionary class and the operations and methods
are similar to dictionary but the only difference is it prevents the key error and initialize for us without us having to initialize
for example: if the keys are not present in the dictionary and we are doing a count, without initializing it would throw a key error but 
default dict fills the gap here and prevents key error by initializing for us




 collections import defaultdict

def group_anagrams(words):
    groups = defaultdict(list)
    for word in words:
        key = tuple(sorted(word))
        groups[key].append(word)
    return list(groups.values())

print(group_anagrams(['eat','tea','tan','ate','nat','bat']))
# [['eat', 'tea', 'ate'], ['tan', 'nat'], ['bat']]

'''

#without the collection module if asked in the interview

def group_anagrams(words):
    groups = {}
    for word in words:
        key = tuple(sorted(word))
        if key not in groups:
            groups[key] = []
        groups[key].append(word)
    return list(groups.values())

print(group_anagrams(['eat','tea','tan','ate','nat','bat']))