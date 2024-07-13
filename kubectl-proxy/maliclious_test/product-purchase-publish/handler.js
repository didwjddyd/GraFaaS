'use strict';

module.exports = (event, context, callback) => {
    
    var purchaseEvent = {};

    if (event.body.approved == 'true') {
	purchaseEvent.productId = event.body.id;
	purchaseEvent.productPrice = event.body.price;
	purchaseEvent.userId = event.body.user;
	purchaseEvent.authorization = event.body.authorization;
    } else {
	if (typeof event.body.failureReason === 'string' || event.body.failureReason instanceof String) {
	    purchaseEvent.failureReason = event.body.failureReason;
	} else {
	    purchaseEvent.failureReason = {...event.body.failureReason};
	}
    }
    return callback(null, purchaseEvent);
  };

