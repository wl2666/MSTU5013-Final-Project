<app>
	<navbar player={ player } room={ room }></navbar>

	<div class="container">
		<div class="row">
			<div class="col">
				<div id="board" if={ room }>
					<h2>Room:{ room.id }</h2>
					<div if={ currentBoard == 'round' } class="row align-items-center ">
						<span style='font-size: 16pt;' class="col-3 badge badge-primary">ROUND: { round }</span>
						<span style='font-size: 16pt;' class="col-3 badge badge-warning">Target Bid: { targetBid }
							<i class="fas fa-coins"></i>
						</span>
						<span if={ currentBoard == 'round' } class="col-3" id="pieTimer">
							<pietimer></pietimer>
						</span>
					</div>

					<div class="table" hide={ currentBoard== "last"}>
						<div id="countDownBoard" if={ currentBoard == 'start' && roomPlayers.length >= 2 } class="clock">
							<timer></timer>
						</div>
						<div id="playBoard" if={ currentBoard == 'round' }>
							<!-- here need to grab data from database to show the highest and second highest players-->

							<div id="highest" hide={ this.highestBid == 0}>{ highestBidder }:{ highestBid }</div>
							<div id="secondHighest" hide={ this.secondHighestBid == 0}>{ secondHighestBidder }:{ secondHighestBid }</div>
						</div>
						<div id="winnerBoard" if={ currentBoard == 'winner' }>
							<i class="fas fa-crown"></i>
							<div><img id="winnerImg" src={ winnerPlayer.photo }></div>
							<div>{ winnerPlayer.name }</div>
						</div>
						<div id="rankBoard" if={ currentBoard == 'rank' }>
							<p id="rank">Rank</p>
							<div each={ roomPlayer in roomPlayers }>
								<img id="rankImg" src={ roomPlayer.photo }>
								<span>
									<strong>{ roomPlayer.name }</strong>
								</span>
								<span class="badge badge-info">{ roomPlayer.balance }</span>
							</div>
						</div>
					</div>
					<button class="btn btn-secondary" type="button" onclick={ toggle } show={ this.currentBoard == 'rank' } disabled={ this.currentBoard !== 'rank' }>Want to learn more about the secret of the game?</button>
					<div if={ currentBoard !== 'rank'} hide={ currentBoard== "last"} each={ roomPlayer in roomPlayers }>
						<!-- <span if={ currentBoard == 'round'} class="badge badge-info"><i class="fas fa-hand-holding-usd"></i>{ here should be every bid that each player make }</span>-->
						<strong>{ roomPlayer.name }</strong>:
						<input id="bidInput" class="mr-sm-2" type="number" onchange={ saveInput } ref="bidInput" placeholder="Enter integer please" show={ currentBoard == 'round' && roomPlayer.name == this.player.displayName }>
						<button class="btn btn-sm btn-success" type="button" onclick={ bid } show={ currentBoard == 'round' && roomPlayer.name == this.player.displayName }>BID</button>
						<span class="badge badge-info" show={ roomPlayer.name == this.player.displayName }>BALANCE : {roomPlayer.balance}</span>
					</div>
					<div if={ currentBoard == 'last' } id="carouselExampleIndicators" class="carousel slide" data-ride="carousel">
						<ol class="carousel-indicators">
							<li data-target="#carouselExampleIndicators" data-slide-to="0" class="active"></li>
							<li data-target="#carouselExampleIndicators" data-slide-to="1"></li>
							<li data-target="#carouselExampleIndicators" data-slide-to="2"></li>
						</ol>
						<div class="carousel-inner">
							<div class="carousel-item active">
								<img class="d-block w-100" src="assets/Presentation1.jpg" alt="First slide">
							</div>
							<div class="carousel-item">
								<img class="d-block w-100" src="assets/Presentation2.jpg" alt="Second slide">
							</div>
							<div class="carousel-item">
								<img class="d-block w-100" src="assets/Presentation3.jpg" alt="Third slide">
							</div>
						</div>
						<a class="carousel-control-prev" href="#carouselExampleIndicators" role="button" data-slide="prev">
							<span class="carousel-control-prev-icon" aria-hidden="true"></span>
							<span class="sr-only">Previous</span>
						</a>
						<a class="carousel-control-next" href="#carouselExampleIndicators" role="button" data-slide="next">
							<span class="carousel-control-next-icon" aria-hidden="true"></span>
							<span class="sr-only">Next</span>
						</a>
					</div>
				</div>
			</div>
		</div>
	</div>

	<script>
		// JAVASCRIPT
		console.log(this);
		let roomsRef = database.collection('player-rooms');

		this.room = null;
		this.roomPlayers = [];
		this.currentBoard = 'start';
		this.countNum = "";
		this.round = 1;
		this.targetBid = (Math.floor(Math.random() * 10 + 1)) * 10;
		this.bids = [];
		this.winnerPlayer={}

		firebase.auth().onAuthStateChanged(playerObj => {
			if (playerObj) {
				this.player = playerObj;
			} else {
				this.player = null;
				this.room = null;
			}
			this.update();
		});

		let stopListening;

		observer.on('exitRoom', () => {
			let roomPlayerRef = database.collection('player-rooms').doc(this.room.id).collection('players').doc(this.player.uid);
			roomPlayerRef.delete().then(() => {
				this.room = null;
				this.currentBoard = 'start';
				this.round = 1;
				this.bids = [];
				this.update();
			});
		});

		observer.on('codeEntered', roomCode => {
			roomsRef.doc(roomCode).get().then(doc => {
				if (!doc.exists) {

					let room = {
						author: this.player.displayName,
						authorID: this.player.uid,
						id: doc.id,
						round: this.round,
						targetBid: this.targetBid,
						bids: this.bids
					}

					doc.ref.set(room);
					this.room = room;

				} else {
					let room = doc.data();
					this.room = room;
				}
				this.update();

				return doc;

			}).then(doc => {
				let roomPlayersRef = doc.ref.collection('players');

				roomPlayersRef.doc(this.player.uid).set({
					id: this.player.uid,
					name: this.player.displayName,
					photo: this.player.photoURL,
					balance: 100});
				return roomPlayersRef;
			}).then(roomPlayersRef => {
				roomPlayersRef.orderBy("balance", "desc").onSnapshot(querySnapshot => {
					this.roomPlayers = [];
					querySnapshot.forEach(doc => {
						this.roomPlayers.push(doc.data());
					});
					this.update();
				});

				//when the number of players in one room is more than 3, it will trigger the timer
				let roomRef = roomsRef.doc(roomCode).collection('players');
				roomRef.get().then(querySnapshot => {
					if (querySnapshot.docs.length >= 2) {
						observer.trigger('timer:start');
					}
					this.update();
				});

				let bidValue;
				saveInput(event) {
					bidValue = parseInt(event.target.value);
				}

				bid(event) {
					//bidTimer starts to count down observer.trigger('bid:start'); grab data from the players' input
					let bidder = event.item.roomPlayer.name;
					let bidsRef = roomsRef.doc(roomCode);

					if (bidValue <= this.highestBid) {
						alert("You should bid higher");
					} else {
						//bidTimer starts to count down
						observer.trigger('bid:start');
						//every time a user makes a bid value higher thatn the current highest, it will be saved to the field 'bids' in database
						bidsRef.update({
							bids: firebase.firestore.FieldValue.arrayUnion({name: bidder, bidValue: bidValue})
						});
					}
				}

				roomsRef.doc(roomCode).onSnapshot(queryDocumentSnapshot => {
					//get bids array data from database
					let bidsArr = queryDocumentSnapshot.data().bids;
					//order data from database(reference to the lodash documentation: https://lodash.com/docs/4.17.11#orderBy
					let highestBidObjects = _.orderBy(bidsArr, ['bidValue'], ['desc']);
					// console.log(highestBidObjects);
					observer.trigger('bid:start');
					if (highestBidObjects.length >= 2) {
						this.highestBid = parseInt(highestBidObjects[0].bidValue);
						this.highestBidder = highestBidObjects[0].name;
						this.secondHighestBid = parseInt(highestBidObjects[1].bidValue);
						this.secondHighestBidder = highestBidObjects[1].name;
					} else if (highestBidObjects.length == 1) {
						this.highestBid = parseInt(highestBidObjects[0].bidValue);
						this.highestBidder = highestBidObjects[0].name;
					} else {
						this.highestBid = 0
						this.highestBidder = ''
						this.secondHighestBid = 0
						this.secondHighestBidder = '';
					}
					this.update();
				});
			});
		});


		recalculateScores() {
			let roomref = database.collection('player-rooms').doc(this.room.id);
			let roomPlayerRef = roomref.collection('players').doc(this.player.uid);
			roomPlayerRef.get().then(querySnapshot => {
				this.player.balance = querySnapshot.data().balance
				if (this.player.displayName == this.highestBidder) {
					this.player.balance = this.player.balance + this.targetBid - this.highestBid
				} else if (this.player.displayName == this.secondHighestBidder) {
					this.player.balance = this.player.balance - this.secondHighestBid
        }

				if(this.highestBidder) {
					for (var i=0; i < this.roomPlayers.length; i++) {
		        if (this.roomPlayers[i].name == this.highestBidder) {
		            this.winnerPlayer = this.roomPlayers[i];
		        }
		      }
				} else {
					return 'No bid this time!'
				}


				roomPlayerRef.set({
					balance: this.player.balance
				}, {merge: true});

				console.log(this.player);
				roomref.update({bids: []});
				this.targetBid = (Math.floor(Math.random() * 10 + 1)) * 10;
				this.update();
			});

		}

		//a function to toggle between start page and round page; only for coding process; delete it after finishing the whole project
		toggle() {
			if (this.currentBoard == 'rank') {
				this.currentBoard = 'last';
			}

			// if (this.currentBoard == 'start') { 	this.currentBoard = 'round'; } else if (this.currentBoard == 'round') { 	this.currentBoard = 'winner'; } else if (this.currentBoard == 'winner') { 	this.currentBoard = 'rank'; } else if (this.currentBoard ==
			// 'rank') { 	this.currentBoard = 'last'; } else if (this.currentBoard == 'last') { 	this.currentBoard = 'start'; }
		}
	</script>

	<style>
		/* CSS */
		:scope {}
		.table {
			width: 600px;
			height: 300px;
			background-color: #f8f9fa;
			text-align: center;
		}
		.badge {
			text-align: center;
		}
		.clock {
			width: 200px;
			height: 200px;
			background-color: #fff;
			margin: auto;
		}
		.carousel-indicators li {
		  background-color: #999;
		  background-color: rgba(70, 70, 70, 0.25);
		}

		.carousel-indicators .active {
		  background-color: #444;
		}
		. #countNum {
			font-size: 100px;
		}
		#bidInput {
			width: 20%;
			border-radius: 30px;
		}
		#winnerBoard {
			background-image: url("assets/falling coin.gif");
			height: 300px;
			width: 600px;
			padding-top: 50px;
			font-size: 50px;
		}
		#playBoard {
			background-image: url("assets/auction.jpg");
			height: 300px;
			width: 600px;
			/* padding-top: 50px; */
			margin-top: 20px;
		}
		#countDownBoard {
			background-image: url("assets/ready.jpg");
			height: 300px;
			width: 600px;
			/* padding-top: 50px; */
			margin-top: 20px;
		}
		#winnerImg {
			width: 60px;
		}
		#rankBoard {
			text-align: center;
			margin-top: 20px;
			background-image: url("assets/rank.gif");
			height: 300px;
			width: 600px;
		}
		#rank {
			font-size: 45px;
			background-color: #4682b4;
		}
		#rankImg {
			width: 30px;
		}
		#board {
			font-family: 'Gugi', cursive;
		}
		#highest {
			font-family: 'Gugi', cursive;
			font-size: 60px;
			color: #FFA07A;
		}
		#secondHighest {
			font-family: 'Gugi', cursive;
			font-size: 45px;
			color: #8FBC8F;
		}
	</style>
</app>
