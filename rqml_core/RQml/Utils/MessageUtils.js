.pragma library


function toJavaScriptObject(msg) {
    if (msg === null || typeof msg !== "object")
        return msg;
    if (typeof msg.toArray === "function") {
        msg = msg.toArray();
    }
    if (Array.isArray(msg)) {
        let arr = [];
        for (let i = 0; i < msg.length; i++) {
            arr.push(toJavaScriptObject(msg[i]));
        }
        return arr;
    }
    let result = {};
    for (let key in msg) {
        result[key] = toJavaScriptObject(msg[key]);
    }
    return result;
}

//! Similar to toJavaScriptObject but ensures that non-object list elements
//! are wrapped in an object with a 'display' field.
//! This enables them to be used in recursive ListViews where the injected
//! model property requires a key to bind the value to.
function toListElement(msg) {
    if (msg === null || typeof msg !== "object")
        return msg;
    if (typeof msg.toArray === "function") {
        msg = msg.toArray();
    }
    if (Array.isArray(msg)) {
        let arr = [];
        for (let i = 0; i < msg.length; i++) {
            if (typeof msg[i] === "object") {
                arr.push(toListElement(msg[i]));
            } else {
                arr.push({ display: msg[i] });
            }
        }
        return arr;
    }
    let result = {};
    for (let key in msg) {
        result[key] = toListElement(msg[key]);
    }
    return result;
}

// Recursively strip empty fields from message for display
function stripEmptyFields(obj) {
    if (obj === 0 || obj === 0.0 || obj === false || obj === "")
        return undefined;
    if (obj === null || typeof obj !== "object")
        return obj ?? undefined;
    if (typeof obj.toArray === "function") {
        obj = obj.toArray();
    }
    if (Array.isArray(obj)) {
        let arr = [];
        for (let i = 0; i < obj.length; i++) {
            const value = stripEmptyFields(obj[i]);
            if (value !== undefined)
                arr.push(value);
        }
        return arr.length === 0 ? undefined : arr;
    }
    let result = {};
    for (let key in obj) {
        if (key.startsWith("#") || key === "clockType")
            continue;
        const value = stripEmptyFields(obj[key]);
        if (value === undefined)
            continue;
        if (typeof value === "object" && Object.keys(value).length === 0)
            continue;
        result[key] = value;
    }
    return result;
}
