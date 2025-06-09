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
     * Look for item name in the line above (within 0.03 vertical tolerance)
     * Extract weight and price per kg using regex patterns
     * Store both the total price and weight information
   - If regular item:
     * Use scoring system to find best matching item name

3. **Item Name Selection Scoring System**
   For each potential item name, calculate a score based on:
   - Horizontal distance (35% weight): Prefer items to the left of price
   - Vertical alignment (25% weight): Prefer items on same row
   - Text length (15% weight): Prefer longer text for item names
   - Letter ratio (15% weight): Prefer text with more letters over numbers
   - Position (10% weight): Prefer items on left side of receipt

4. **Special Cases**
   - Handle weight-based items (e.g., "1.220 kg @ $1.30/kg")
   - Handle count-based items (e.g., "2 @ $2.00")
   - Process multi-line items (item name above weight/price)
   - Filter out receipt headers and footers

## Coordinate System
- x-coordinate: Vertical position (top to bottom)
- y-coordinate: Horizontal position (left to right)
- All coordinates are normalized (0 to 1)
- Bounding boxes include width and height for text size

## Output
Each processed item includes:
- Item name
- Price
- Bounding box coordinates
- Optional weight and price per kg for weight-based items


