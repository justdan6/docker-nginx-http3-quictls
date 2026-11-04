// Regression coverage for nginx/njs#1143 on 64-bit big-endian platforms.
const outer = 40;
function add(value) {
    let result = outer + value;
    return result;
}
if (add(2) !== 42) {
    throw new Error('njs lexical scope is broken');
}
console.log('Passed njs lexical scope');
