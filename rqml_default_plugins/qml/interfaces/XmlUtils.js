.pragma library

function findElementsByTagName(element, tagName) {
    let result = [];
    if (element.nodeName === tagName)
        result.push(element);
    const children = element.childNodes || [];
    for (let i = 0; i < children.length; i++)
        result = result.concat(findElementsByTagName(children[i], tagName));
    return result;
}

function getChildByTagName(element, tagName) {
    const children = element.childNodes || [];
    for (let i = 0; i < children.length; i++) {
        if (children[i].nodeName === tagName)
            return children[i];
    }
    return null;
}

function getChildrenByTagName(element, tagName) {
    let result = [];
    const children = element.childNodes || [];
    for (let i = 0; i < children.length; i++) {
        if (children[i].nodeName === tagName)
            result.push(children[i]);
    }
    return result;
}

function getAttributeValue(element, attributeName) {
    if (element && element.attributes) {
        for (let i = 0; i < element.attributes.length; i++) {
            const attr = element.attributes[i];
            if (attr.nodeName === attributeName)
                return attr.nodeValue;
        }
    }
    return "";
}
