const Koa = require('koa');
const logger = require('koa-logger');
const { koaBody } = require('koa-body');
const service = require('./service');

const app = new Koa();

app.use(logger());

app.use(koaBody({ multipart: true }));

app.use(service.routes());

app.listen(8000);

console.log('app start linsten port: 8000');
