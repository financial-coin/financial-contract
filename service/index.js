
const Router = require('@koa/router');

const router = new Router();

router.post('swap-eth', async (ctx) => {
    try {
        const { signed_transcation } = ctx.request.body;
        ctx.body = {};
    } catch (error) {
        ctx.throw(400, err);
    }
})

module.exports = router;