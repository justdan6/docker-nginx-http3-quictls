// @see https://nginx.org/en/docs/njs/
// @see https://nginx.org/en/docs/njs/reference.html
function hello(r) {
    r.warn('njs handler entered');
    r.headersOut['x-njs'] = '1';
    r.warn('njs response header set');
    r.return(200, `Hello world from njs v${njs.version}\n`);
    r.warn('njs response returned');
}

export default {hello};
