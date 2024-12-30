
const Router = require('@koa/router');
const { getAddress, getBigInt, Signature, Transaction } = require('ethers');
const { swapQuote, checkAndSwapETH, startUpdateNetValue } = require('./chain');

const router = new Router();

router.get('/quote', async (ctx) => {
    ctx.body = swapQuote();
});

router.post('/swap', async (ctx) => {
    try {
        ctx.request.socket.setTimeout(60 * 1000);
        const { owner, token, amountIn, amountOut, signature, approveTranscation } = ctx.request.body;
        ctx.body = await checkAndSwapETH(
            getAddress(owner),
            getAddress(token),
            getBigInt(amountIn),
            getBigInt(amountOut),
            Signature.from(signature).serialized,
            Transaction.from(approveTranscation),
        );
    } catch (error) {
        ctx.throw(400, error);
    }
});

// startUpdateNetValue();

module.exports = router;