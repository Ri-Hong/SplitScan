# SplitSnap Receipt Processing Algorithm

## Overview
SplitSnap processes receipt images to extract items and their prices using a combination of text recognition and spatial analysis. The Apple vision framework returns a list of recognized text and their location on the image. We then apply an algorithm to group items with thier price, determine quantity, idenfity taxable items, etc.

## Algorithm Steps

1. **Price Column Detection**
   - Identify all prices (decimal numbers with 2 decimal places)
   - Group prices by their x-coordinate (horizontal position)
   - Find the most common x-coordinate to determine the price column
   - Use a tolerance of 0.05 to group nearby prices

2. **Item Processing**
   For each price in the price column:
   
   a. **Same Line Analysis**
   - Look for text on the same line as the price (within 0.01 vertical tolerance)
   - Filter out header/footer text (e.g., "TOTAL", "THANK YOU", etc.)
   - Consider only text to the left of the price

   b. **Weight-Based Item Detection**
   - Check if the line contains weight indicators ("@", "/kg", "kg")
   - If weight-based:
     * Search line by line above the price line (up to 5 lines)
     * Use scoring system to find the best matching item name
     * Extract weight and price per kg using regex patterns
     * Store both the total price and weight information
   - If regular item:
     * Use scoring system to find best matching item name

3. **Tax Detection**
   - Check if tax codes are present in the item name or on the same line as the price
   - HMRJ = item is taxed
   - MRJ = item is not taxed (but still a tax code)
   - Set the `isTaxed` property based on HMRJ detection
   - Both HMRJ and MRJ codes are removed from the final item name during cleaning

4. **Item Name Selection Scoring System**
   For each potential item name, calculate a score based on:
   - Horizontal distance (30% weight): Prefer items to the left of price
   - Line proximity (30% weight): Prefer items closer to price line, but allow for gaps
   - Text length (15% weight): Prefer longer text for item names
   - Letter ratio (15% weight): Prefer text with more letters over numbers
   - Position (10% weight): Prefer items on left side of receipt

5. **Line-by-Line Search for Weight-Based Items**
   - Search each line above the price line systematically
   - Use approximate line spacing of 0.02 to identify line positions
   - Score each potential item name found on each line
   - Stop searching when a good match is found (score > 0.5) or after 5 lines
   - This handles cases where item names are separated from prices by multiple lines

6. **Special Cases**
   - Handle weight-based items (e.g., "1.220 kg @ $1.30/kg")
   - Handle count-based items (e.g., "2 @ $2.00")
   - Process multi-line items (item name above weight/price)
   - Filter out receipt headers and footers
   - Detect and track tax status for items

## Coordinate System
- x-coordinate: Vertical position (top to bottom)
- y-coordinate: Horizontal position (left to right)
- All coordinates are normalized (0 to 1)
- Bounding boxes include width and height for text size

## Output
Each processed item includes:
- Item name (cleaned, with tax codes removed)
- Price
- Bounding box coordinates
- Optional weight and price per kg for weight-based items
- Tax status (isTaxed boolean)


