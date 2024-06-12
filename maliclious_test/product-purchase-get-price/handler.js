'use strict';

function randomPrice() {
    var cents = Math.floor(Math.random() * 100);
    var dollars = Math.floor(Math.random() * 100);

    return (dollars + (cents * 0.01)).toFixed(2);
}

module.exports = (event, context, callback) => {

    var response = {};

    if (Math.random() < 0.9) {
	response.gotPrice = 'true';
	response.price = randomPrice();

	callback(null, response);
    } else {
	response.gotPrice = 'false';
	response.failureReason = 'No price in the catalog.';

	callback(null, response);
    }
};
