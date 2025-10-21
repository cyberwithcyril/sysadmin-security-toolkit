# Data Generator Code Explanation

**Script:** `data/generators/generate_test_users.py`  
**Author:** Cyril Thomas  
**Purpose:** Understanding how the Faker data generator works

---

## Overview

This script generates realistic fake user data (names, emails, departments, groups) for testing system administration automation scripts.

## Key Components

### 1. Imports
```python
from faker import Faker  # Generates fake data
import csv               # Reads/writes CSV files
import random            # Makes random choices
import argparse          # Handles command-line arguments
```

### 2. Faker Initialization
```python
fake = Faker()
Faker.seed(42)  # Makes data reproducible
```
**Why seed(42)?** Always generates the same "random" data for reproducibility in research.

### 3. Company Structure
```python
DEPARTMENTS = ['IT', 'Sales', 'Marketing', 'Finance', 'HR', 'Operations', 'Legal']

GROUPS = {
    'IT': ['developers', 'sysadmins', 'devops', 'support'],
    'Sales': ['sales', 'account_managers', 'business_dev'],
    'Marketing': ['marketing', 'content', 'social_media'],
    'Finance': ['finance', 'accounting', 'analysts'],
    'HR': ['hr', 'recruiters', 'training'],
    'Operations': ['operations', 'logistics', 'facilities'],
    'Legal': ['legal', 'compliance']
}
```

### 4. Helper Functions

#### generate_username(full_name)
Converts full name to username format.

**Example:**
- "John Smith" → "jsmith"
- "Mary O'Brien" → "mobrien"
- "Alice" → "alice"

**Implementation:**
- Take first letter of first name
- Combine with full last name
- Remove special characters (apostrophes, hyphens)
- Convert to lowercase

#### generate_email(username, domain)
Creates corporate email address from username.

**Example:**
- "jsmith" → "jsmith@techcorp.com"

#### select_groups(department)
Picks 1-2 appropriate groups for the department.

**Example:**
- IT department → might get "developers;sysadmins"
- Sales department → might get "sales;account_managers"

**Logic:**
- Only selects groups that make sense for department
- Randomly chooses 1 or 2 groups
- Joins multiple groups with semicolon separator

#### generate_expiry_date()
Creates random account expiration date 6-24 months in future.

**Example:**
- Today: October 17, 2025
- Possible dates: April 2026 to October 2027

**Format:** YYYY-MM-DD (e.g., "2026-08-15")

### 5. Main Generation Function: generate_users()

**Flow:**
1. **Setup:** Initialize tracking variables
2. **Open CSV:** Create output file
3. **Write Header:** Column names
4. **Loop:** For each user:
   - Generate fake name (Faker)
   - Create username (handle duplicates)
   - Pick random department
   - Select appropriate groups
   - Generate email
   - Create expiry date
   - Write row to CSV
   - Show progress every 10 users
5. **Display Sample:** Show first few users created

**Duplicate Handling:**
```python
# If "jsmith" already exists:
# Try "jsmith2", then "jsmith3", etc.
```

### 6. Command-Line Interface

**Usage Examples:**
```bash
# Default (50 users to ../input/test_users.csv)
python generate_test_users.py

# Custom count
python generate_test_users.py --count 100

# Custom output file
python generate_test_users.py --output myfile.csv

# Both custom
python generate_test_users.py -c 200 -o large.csv

# Short form
python generate_test_users.py -c 10 -o small.csv

# Help
python generate_test_users.py --help
```

## Example Output

**Command:**
```bash
python generate_test_users.py --count 10 --output test.csv
```

**Console Output:**
```
🚀 Generating 10 test users...
  ✓ Generated 10/10 users...

✅ Successfully generated 10 users in test.csv

📋 Sample of generated data:
  username,fullname,email,department,groups,account_expiry
  ahill,Allison Hill,ahill@techcorp.com,Operations,logistics;operations,2026-04-12
  byang,Brian Yang,byang@techcorp.com,Sales,sales,2026-12-18
  jjohnson,Javier Johnson,jjohnson@techcorp.com,Sales,business_dev;sales,2026-04-08
```

**CSV File Contents:**
```csv
username,fullname,email,department,groups,account_expiry
ahill,Allison Hill,ahill@techcorp.com,Operations,logistics;operations,2026-04-12
byang,Brian Yang,byang@techcorp.com,Sales,sales,2026-12-18
jjohnson,Javier Johnson,jjohnson@techcorp.com,Sales,business_dev;sales,2026-04-08
pgarcia,Patricia Garcia,pgarcia@techcorp.com,IT,devops;sysadmins,2026-09-23
...
```

## Key Python Concepts Used

### Functions
Reusable blocks of code with parameters and return values.
```python
def my_function(input_param):
    result = input_param * 2
    return result
```

### Data Structures
- **Lists:** Ordered collections `['item1', 'item2']`
- **Dictionaries:** Key-value pairs `{'key': 'value'}`
- **Sets:** Unique items, fast lookups `{'item1', 'item2'}`

### String Formatting
F-strings for readable string interpolation:
```python
name = "John"
message = f"Hello {name}!"  # "Hello John!"
```

### File I/O
Safe file handling with context managers:
```python
with open('file.csv', 'w') as f:
    f.write('data')
# File automatically closed, even if error occurs
```

### Loops
Repeating operations:
```python
while count < 10:
    # Do something
    count += 1
```

### Command-Line Arguments
Using argparse for user input:
```python
parser.add_argument('--count', type=int, default=50)
args = parser.parse_args()
```

## Design Decisions

### Why Use Seed?
- Reproducible results for research
- Same seed → same data every time
- Critical for verifying research findings
- Professor can regenerate exact same data

### Why Department-Specific Groups?
- Realistic organizational structure
- Tests that scripts handle different group combinations
- Prevents nonsensical assignments (IT person in "sales" group)

### Why Semicolon Separator?
- Common in Unix/Linux systems
- Easy to split: `"group1;group2".split(';')`
- Compatible with CSV format (no conflicts with commas)

### Why 6-24 Month Expiry Range?
- Realistic for temporary/contractor accounts
- Tests account expiration features
- Provides variety in test data

## Possible Modifications

### 1. Add New Departments
```python
DEPARTMENTS = ['IT', 'Sales', 'Marketing', 'Finance', 'HR', 'Operations', 'Legal', 'Engineering', 'Support']
```

### 2. Change Email Domain
```python
def generate_email(username, domain="mycompany.org"):
    return f"{username}@{domain}"
```

### 3. Adjust Expiry Range
```python
# 1-3 years instead of 6-24 months
expiry = fake.date_between(start_date='+1y', end_date='+3y')
```

### 4. Add Phone Numbers
```python
phone = fake.phone_number()
writer.writerow([username, full_name, email, phone, department, groups, expiry])
```

### 5. Change Username Format
```python
# firstname.lastname instead of first_initial + lastname
def generate_username(full_name):
    parts = full_name.lower().split()
    return f"{parts[0]}.{parts[-1]}"  # "john.smith"
```

## Why This Implementation is Good

✅ **Well-organized:** Separate functions for each task  
✅ **Documented:** Clear comments and docstrings  
✅ **Error-handling:** Prevents duplicate usernames  
✅ **Flexible:** Command-line arguments for customization  
✅ **Reproducible:** Seeded random generation  
✅ **User-friendly:** Progress indicators and sample output  
✅ **Realistic:** Department-appropriate group assignments  
✅ **Scalable:** Can generate any number of users  
✅ **Maintainable:** Clean code structure, easy to modify  

## Testing Strategy

### Generated Datasets

**Small (10 users):** Quick functional testing
```bash
python generate_test_users.py -c 10 -o ../input/test_small.csv
```

**Medium (50 users):** Demos and screenshots
```bash
python generate_test_users.py -c 50 -o ../input/test_medium.csv
```

**Large (100+ users):** Stress testing and performance
```bash
python generate_test_users.py -c 100 -o ../input/test_large.csv
```

## Integration with Project

This data will be used by:
1. **User creation scripts** - Create actual users from CSV
2. **Backup scripts** - Backup user home directories
3. **Permission scripts** - Set correct group permissions
4. **Testing scripts** - Verify automation works correctly
5. **Research analysis** - Measure time savings and error rates

---

**Created:** October 17, 2025  
**Last Updated:** October 17, 2025  
**Author:** Cyril Thomas
