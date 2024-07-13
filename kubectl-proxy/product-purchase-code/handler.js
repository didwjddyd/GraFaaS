"use strict"

const request = require('request-promise')

const constants = {
    URL_GETPRICE: process.env.URL_GETPRICE,
    URL_AUTHORIZECC: process.env.URL_AUTHORIZECC,
    URL_PUBLISH: process.env.URL_PUBLISH,
};

const functions = {
    getRequestObject: (requestVals, url) => {
        return {
            method: 'POST',
            uri: url,
            body: requestVals,
            json: true,
        }
    }
}

const api = {
    purchaseProduct: async (event, context, callback) => {
	    console.log("Incoming event:");
	    console.log(event);
	
		var getPriceData = {
			"id": event.body["id"]
			};


		if (event.body.cfattack) {
			console.log("Control flow attack - skipping auth and making purchase");
			var reqs = [
				request(functions.getRequestObject(getPriceData, constants.URL_GETPRICE), constants.URL_GETPRICE)
				];
		
			Promise.all(reqs).then(res => {
				console.log("get-price response:")
				console.log(res);
		
				var publishData = {
					approved: 'true',
					id: event.body.id,
					price: res[0].price,
					user: event.body.user,
					authorization: 1234567890,
				};
	
			request(functions.getRequestObject(publishData, constants.URL_PUBLISH), constants.URL_PUBLISH)
				.then(publishRes => {
	
				console.log('Publish response:');
				console.log(publishRes);
	
				var respData = {};
	
				if (publishRes.failureReason) {
					if (typeof publishRes.failureReason === 'string' || publishRes.failureReason instanceof String) {
					respData.failureReason = publishRes.failureReason;
					} else {
					respData.failureReason = {...publishRes.failureReason};
					}
				} else {
					respData.success = 'true';
					respData.chargedAmount = publishRes.productPrice;
					respData.authorization = publishRes.authorization;
				}
	
				var finalResponse = {
					...respData
				};
	
				callback(null, finalResponse);
				});
			});
	
			return;
		}

	    
	    var authorizeCCData = {
		"user": event.body["user"],
		"creditCard": event.body["creditCard"]
	    };

	    if (event.body.malicious) {
		authorizeCCData.malicious = event.body.malicious;
		authorizeCCData.attackserver = event.body.attackserver;
	    }

	    var reqs = [
		request(functions.getRequestObject(getPriceData, constants.URL_GETPRICE), constants.URL_GETPRICE),
		request(functions.getRequestObject(authorizeCCData, constants.URL_AUTHORIZECC), constants.URL_AUTHORIZECC)
	    ];

	    Promise.all(reqs).then(res => {
		console.log("get-price and authorize-cc responses:")
		console.log(res);

		var publishData = {
		    id: event.body.id,
		    price: res[0].price,
		    user: event.body.user,
		    authorization: res[1].authorization
		};

		if (res[0].gotPrice == 'false') {
		    publishData.approved = 'false';
		    publishData.failureReason = res[0].failureReason;
		} else if (res[1].approved == 'false') {
		    publishData.approved = 'false';
		    publishData.failureReason = res[1].failureReason;
		} else {
		    publishData.approved = 'true';
		}
    
		request(functions.getRequestObject(publishData, constants.URL_PUBLISH), constants.URL_PUBLISH)
		    .then(publishRes => {
			console.log('publish response:');
			console.log(publishRes);

			var respData = {};

			if (publishRes.failureReason) {
			    if (typeof publishRes.failureReason === 'string' || publishRes.failureReason instanceof String) {
				respData.failureReason = publishRes.failureReason;
			    } else {
				respData.failureReason = {...publishRes.failureReason};
			    }
			} else {
			    respData.success = 'true';
			    respData.chargedAmount = publishRes.productPrice;
			    respData.authorization = publishRes.authorization;
			}

			var finalResponse = {
			    ...respData
			};


			if (false) {
			    finalResponse.debug = {
				getPrice: res[0],
				authCC: res[1],
				publish: publishRes
			    }
			}

			console.log("Outgoing response:");
			console.log(finalResponse);

			callback(null, finalResponse);
		    })
	    });
	}
}

module.exports = (event, context, callback) => {
    console.log('abcd')
    api.purchaseProduct(event, context, callback);
}
