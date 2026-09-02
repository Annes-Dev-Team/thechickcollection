
function PARSELIST(array, into) {
    // 2. Select the parent container element
    const container = document.getElementById(into);

    // 3. Loop through the array
    array.forEach((item) => {
        // Create a new HTML element (e.g., <li>)
        const listItem = document.createElement('li');
        const label = document.createElement('label');
        const checkbox = document.createElement("input")
        checkbox.type='checkbox';
        checkbox.checked = item.done;
        checkbox.disabled = true;
        // Assign the array text to the element
        label.appendChild(checkbox)
        listItem.textContent = item.name;
        listItem.appendChild(label)

        // Append the new element into the container
        container.appendChild(listItem);
    });
}
