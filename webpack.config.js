var path = require("path");
var webpack = require("webpack");

module.exports = {
	cache: true,
	entry: {
		birch: "./lib",
		demo: "./browser/demo",
		specs: "./browser/specs"
	},
	output: {
		path: path.join(__dirname, "dist"),
		publicPath: "dist/",
		filename: "[name].js",
		chunkFilename: "[chunkhash].js"
	},
	module: {
		loaders: [
			// required to write "require('./style.css')"
			//{ test: /\.less$/, loader: "style-loader!css-loader!autoprefixer-loader!less-loader" },
			{ test: /\.less$/, loader: "css-loader!autoprefixer-loader!less-loader" },


			{ test: /\.js$/, exclude: /node_modules/, loader: '6to5-loader'},
			{ test: /\.coffee$/, loader: "6to5-loader!coffee-loader" },
			{ test: /\.cson$/, loader: "cson-loader" },

			// required for json
			{ test: /\.json$/,    loader: "json-loader" },

			// required for bootstrap icons
			{ test: /\.woff$/,   loader: "url-loader?prefix=font/&limit=5000&mimetype=application/font-woff" },
			{ test: /\.ttf$/,    loader: "file-loader?prefix=font/" },
			{ test: /\.eot$/,    loader: "file-loader?prefix=font/" },
			{ test: /\.svg$/,    loader: "file-loader?prefix=font/" },

			{ test: /\.spec.js$/,   loader: "mocha-loader" }
		]
	},
	resolve: {
		alias: {
			birch: path.join(__dirname, "lib"),
			atom: path.join(__dirname, "browser/atom"),
			specs: path.join(__dirname, "browser/specs"),
		},
		extensions: ['', '.webpack.js', '.web.js', '.js', '.coffee'],  // Look for *.coffee files when resolving modules
	},
	plugins: [
		new webpack.ProvidePlugin({
		})
	]
};